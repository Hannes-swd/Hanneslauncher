// The recordings from the emulator, one <video> per clip, shared: the 3D
// phone uses them as textures, and without WebGL the same element goes into
// the slot's CSS phone. Nothing downloads until a clip is first asked for.

const cache = new Map<string, HTMLVideoElement>();

export function getClip(name: string): HTMLVideoElement {
  let v = cache.get(name);
  if (!v) {
    v = document.createElement('video');
    v.muted = true;
    v.defaultMuted = true;
    v.playsInline = true;
    v.loop = true;
    v.preload = 'auto';
    v.crossOrigin = 'anonymous';
    v.setAttribute('muted', '');
    v.setAttribute('playsinline', '');
    v.setAttribute('aria-hidden', 'true');
    v.src = `/media/clips/${name}.mp4`;
    cache.set(name, v);
  }
  return v;
}

export function play(v: HTMLVideoElement, fromStart = false) {
  if (fromStart) v.currentTime = 0;
  const p = v.play();
  if (p) p.catch(() => { /* autoplay refused (battery saver): the poster stays */ });
}

/** No WebGL: each slot plays its own clip inside the CSS phone while visible. */
export function fallbackSlots() {
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        const slot = e.target as HTMLElement;
        const name = slot.dataset.clip;
        if (!name) continue;
        const v = getClip(name);
        if (e.isIntersecting) {
          const frame = slot.querySelector('.phone-css')!;
          if (v.parentElement !== frame) frame.replaceChildren(v);
          play(v);
        } else v.pause();
      }
    },
    { rootMargin: '10% 0px' },
  );
  document.querySelectorAll<HTMLElement>('[data-slot][data-clip]').forEach((s) => io.observe(s));
}

/** The flat clip cards (draw, search) play only while on screen. */
export function clipCards() {
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        const v = e.target as HTMLVideoElement;
        if (e.isIntersecting) {
          if (!v.src) v.src = `/media/clips/${v.dataset.clipVideo}.mp4`;
          play(v);
        } else v.pause();
      }
    },
    { threshold: 0.35 },
  );
  document.querySelectorAll<HTMLVideoElement>('[data-clip-video]').forEach((v) => io.observe(v));
}
