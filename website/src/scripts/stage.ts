// The 3D phone (public/models/phone.glb, built in Blender by
// _source/blender/build_phone.py). One phone for the whole page: it sits in
// whichever [data-slot] is on stage, matching the slot's size and place
// exactly - so the HTML decides the layout at every screen size - and flies
// to the next slot when the page moves on, turning once on the way.

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import { getClip, play } from './clips';

const PHONE_H = 0.15843; // metres, the model's height
const FOV = 20;
const DIST = 1;
const FLIGHT = 1.05; // seconds

type Pose = { x: number; y: number; s: number; yaw: number; pitch: number; roll: number };
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const ease = (t: number) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);
const rad = THREE.MathUtils.degToRad;

export async function startStage(canvas: HTMLCanvasElement) {
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = 1.0;

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.03).texture;
  scene.environmentIntensity = 0.95;
  const key = new THREE.DirectionalLight(0xfff8f0, 1.4);
  key.position.set(-0.6, 0.8, 1.0);
  scene.add(key);

  const camera = new THREE.PerspectiveCamera(FOV, 1, 0.01, 10);
  camera.position.set(0, 0, DIST);
  const visibleH = 2 * Math.tan(rad(FOV / 2)) * DIST;

  let isMobileDevice = innerWidth < 768;

  // ---- the model ----------------------------------------------------------
  const gltf = await new GLTFLoader().loadAsync('/models/phone.glb');
  const model = gltf.scene;
  // Blender's Z-up comes in as Y-up: the phone lies on its back with its top
  // towards -Z. A quarter turn about X stands it up, screen to the camera.
  model.rotation.x = Math.PI / 2;
  const phone = new THREE.Group();
  phone.add(model);
  scene.add(phone);

  // the display: two copies of the screen mesh so clips can crossfade
  const screenA = model.getObjectByName('Screen') as THREE.Mesh;
  const matA = new THREE.MeshBasicMaterial({ toneMapped: false, color: 0xffffff });
  screenA.material = matA;
  const screenB = screenA.clone();
  const matB = new THREE.MeshBasicMaterial({ toneMapped: false, transparent: true, opacity: 0, depthWrite: false });
  screenB.material = matB;
  screenB.position.z += 0.00001;
  screenB.renderOrder = 2;
  screenA.parent!.add(screenB);

  // the glass picks up a little more of the room than the metal
  model.traverse((o) => {
    const m = (o as THREE.Mesh).material as THREE.MeshStandardMaterial | undefined;
    if (!m || !('envMapIntensity' in m)) return;
    if (m.name === 'Glass' || m.name === 'Lens') m.envMapIntensity = 1.3;
    if (m.name === 'Frame' || m.name === 'Ring') m.envMapIntensity = 1.15;
  });

  // a soft drop shadow on the page behind the phone, thrown down and to the
  // right like the launcher's key light
  const sh = document.createElement('canvas');
  sh.width = 160; sh.height = 320;
  const g = sh.getContext('2d')!;
  g.filter = 'blur(26px)';
  g.fillStyle = '#000';
  g.beginPath();
  g.roundRect(44, 52, 72, 216, 30);
  g.fill();
  const shadowTex = new THREE.CanvasTexture(sh);
  const shadow = new THREE.Mesh(
    new THREE.PlaneGeometry(0.0745 * 1.75, PHONE_H * 1.4),
    new THREE.MeshBasicMaterial({ map: shadowTex, transparent: true, opacity: 0.22, depthWrite: false, color: 0x1b1a17 }),
  );
  shadow.renderOrder = -1;
  scene.add(shadow);

  // ---- textures for clips and stills --------------------------------------
  const textures = new Map<string, THREE.Texture>();
  const loader = new THREE.TextureLoader();
  function textureFor(slot: HTMLElement): THREE.Texture {
    const key = slot.dataset.clip ?? slot.dataset.screen ?? '';
    let tex = textures.get(key);
    if (!tex) {
      if (slot.dataset.clip) tex = new THREE.VideoTexture(getClip(slot.dataset.clip));
      else tex = loader.load(slot.dataset.screen!);
      tex.colorSpace = THREE.SRGBColorSpace;
      tex.flipY = false; // glTF UVs
      tex.generateMipmaps = true;
      tex.magFilter = THREE.LinearFilter;
      tex.minFilter = THREE.LinearMipmapLinearFilter;
      tex.anisotropy = isMobileDevice ? 2 : Math.min(8, renderer.capabilities.getMaxAnisotropy());
      textures.set(key, tex);
    }
    return tex;
  }

  // ---- slots ---------------------------------------------------------------
  const slots = [...document.querySelectorAll<HTMLElement>('[data-slot]')];
  let w = 1, h = 1;

  function poseOf(slot: HTMLElement): Pose {
    const r = slot.getBoundingClientRect();
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    const aspect = w / h;
    return {
      x: ((cx / w) * 2 - 1) * (visibleH * aspect) / 2,
      y: -((cy / h) * 2 - 1) * visibleH / 2,
      s: (r.height / h) * visibleH / PHONE_H,
      yaw: Number(slot.dataset.yaw ?? 0),
      pitch: Number(slot.dataset.pitch ?? 0),
      roll: Number(slot.dataset.roll ?? 0),
    };
  }

  /** The slot on stage: the visible one closest to the middle of the screen. */
  function pick(): HTMLElement | null {
    let best: HTMLElement | null = null;
    let bestD = Infinity;
    for (const s of slots) {
      const r = s.getBoundingClientRect();
      if (r.bottom < h * 0.12 || r.top > h * 0.88 || r.width === 0) continue;
      const d = Math.abs(r.top + r.height / 2 - h / 2);
      if (d < bestD) { bestD = d; best = s; }
    }
    return best;
  }

  let current: HTMLElement | null = null;
  let from: Pose | null = null;
  let flightT = 1;
  let spin = 0;
  let fade = 1; // 0..1 crossfade from A to B
  let shown: HTMLElement | null = null; // slot whose texture is on screen A

  function setScreen(slot: HTMLElement, instant = false) {
    const tex = textureFor(slot);
    if (slot.dataset.clip) play(getClip(slot.dataset.clip), true);
    if (instant || !matA.map) {
      matA.map = tex; matA.needsUpdate = true;
      shown = slot;
      return;
    }
    matB.map = tex; matB.needsUpdate = true;
    fade = 0;
  }

  // pointer parallax - disabled on touch devices to prevent jitter on mobile
  let px = 0, py = 0, tpx = 0, tpy = 0;
  const isTouch = () => matchMedia('(hover: none)').matches;
  if (!isTouch()) {
    addEventListener('pointermove', (e) => {
      tpx = (e.clientX / innerWidth) * 2 - 1;
      tpy = (e.clientY / innerHeight) * 2 - 1;
    }, { passive: true });
  }

  function resize() {
    w = canvas.clientWidth;
    h = canvas.clientHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
  }
  new ResizeObserver(resize).observe(canvas);
  resize();

  let last = performance.now();
  let rendered: Pose | null = null;
  let running = true;
  document.addEventListener('visibilitychange', () => {
    running = !document.hidden;
    if (running) { last = performance.now(); requestAnimationFrame(frame); }
  });

  function frame(now: number) {
    if (!running) return;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;

    const next = pick();
    if (next && next !== current) {
      from = rendered ? { ...rendered } : null;
      const far = rendered ? Math.abs(poseOf(next).y - rendered.y) > visibleH * 0.4 : false;
      spin = far ? Math.PI * 2 * (Math.random() < 0.5 ? 1 : -1) : 0;
      flightT = from ? 0 : 1;
      current = next;
      // pause the clip we are leaving
      if (shown?.dataset.clip && shown !== next) getClip(shown.dataset.clip).pause();
      setScreen(next, !from);
    }

    if (current) {
      const target = poseOf(current);
      let p: Pose;
      if (flightT < 1 && from) {
        flightT = Math.min(1, flightT + dt / FLIGHT);
        const k = ease(flightT);
        p = {
          x: lerp(from.x, target.x, k),
          y: lerp(from.y, target.y, k),
          s: lerp(from.s, target.s, k),
          yaw: lerp(from.yaw, target.yaw, k),
          pitch: lerp(from.pitch, target.pitch, k),
          roll: lerp(from.roll, target.roll, k),
        };
        // halfway, while it is turned away, the screen changes
        if (flightT > 0.45 && fade === 0) fade = 0.0001;
      } else p = target;
      rendered = p;

      px = lerp(px, tpx, 0.06);
      py = lerp(py, tpy, 0.06);
      const t = now / 1000;
      const turn = spin * ease(flightT) - spin;
      const bobAmount = isMobileDevice ? 0 : 0.0012;
      const sineAmount = isMobileDevice ? 0 : 0.6;
      const parallaxX = isMobileDevice ? 0 : px * 7;
      const parallaxY = isMobileDevice ? 0 : py * 4;
      phone.position.set(p.x, p.y + Math.sin(t * 0.9) * bobAmount * p.s, 0);
      phone.scale.setScalar(p.s);
      phone.rotation.set(
        rad(p.pitch + parallaxY + Math.sin(t * 0.7) * sineAmount),
        rad(p.yaw + parallaxX) + turn,
        rad(p.roll),
        'YXZ',
      );
      shadow.position.set(p.x + 0.012 * p.s, p.y - 0.016 * p.s, -0.06 * p.s);
      shadow.scale.setScalar(p.s * (1 + Math.abs(Math.sin(turn)) * 0.15));
      shadow.rotation.z = rad(p.roll);
      (shadow.material as THREE.MeshBasicMaterial).opacity = 0.2 * (1 - Math.abs(Math.sin(turn / 2)) * 0.5);
    }

    // crossfade the display - simplified on mobile to reduce flickering
    if (fade > 0 && fade < 1) {
      const crossfadeDuration = isMobileDevice ? 0.15 : 0.3;
      fade = Math.min(1, fade + dt / crossfadeDuration);
      matB.opacity = fade;
      matB.needsUpdate = true;
      if (fade >= 1) {
        matA.map = matB.map; matA.needsUpdate = true;
        matB.opacity = 0;
        matB.needsUpdate = true;
        shown = current;
      }
    }

    renderer.render(scene, camera);
    requestAnimationFrame(frame);
  }

  // first frame before revealing, so nothing pops in empty
  const first = pick() ?? slots[0];
  if (first) {
    current = first;
    setScreen(first, true);
    rendered = poseOf(first);
  }
  requestAnimationFrame(frame);
  return { renderer };
}
