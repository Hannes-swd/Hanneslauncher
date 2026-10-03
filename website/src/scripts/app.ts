// Wires the page up. Motion is built only when the visitor hasn't asked
// their system for less of it; without it every chapter is a plain,
// complete layout (the CSS checks html.motion, set in the <head>).

import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { SplitText } from 'gsap/SplitText';
import Lenis from 'lenis';
import { goTo, setScroller } from './nav';
import { initLetterBar } from './letterbar';
import { clipCards, fallbackSlots, getClip } from './clips';
import { refreshReleases } from './releases';
import { initDesign } from './design';
import { initStream } from './stream';

gsap.registerPlugin(ScrollTrigger, SplitText);
const root = document.documentElement;
const motion = root.classList.contains('motion');
const narrow = () => innerWidth < 760;

initDesign();
initLetterBar();
clipCards();
alphabetSteps();
refreshReleases();
initStream();
downloadThenGuide();

if (motion) {
  const lenis = new Lenis({ lerp: 0.11, smoothWheel: true });
  lenis.on('scroll', ScrollTrigger.update);
  gsap.ticker.add((time) => lenis.raf(time * 1000));
  gsap.ticker.lagSmoothing(0);
  setScroller(lenis);

  document.fonts.ready.then(() => {
    heroIntro();
    noteWords();
    titles();
    // pinned chapters must be set up top to bottom, or the later ones
    // measure their start without the earlier ones' pin space
    why();
    hscroll('#panel');
    clocks();
    stream();
    night();
    hscroll('#updates');
    ScrollTrigger.refresh();
  });
}
stars();
startStage();

// ---------------------------------------------------------------------------

function heroIntro() {
  // two word marks exist (one line, two lines); only the one on show animates
  const words = [...document.querySelectorAll<SVGSVGElement>('[data-dotword]')].filter((s) => s.getBoundingClientRect().width > 0);
  const tl = gsap.timeline({ defaults: { ease: 'expo.out' } });
  for (const word of words) {
    const box = word.viewBox.baseVal;
    const on = word.querySelectorAll('.dotword-on circle');
    const off = word.querySelectorAll('.dotword-off circle');
    // the lit dots start as a field of stars and settle into letters
    tl.from(on, {
      x: () => gsap.utils.random(-box.width * 0.3, box.width * 0.3),
      y: () => gsap.utils.random(-box.height * 3, box.height * 2.5),
      scale: () => gsap.utils.random(0.2, 1.4),
      opacity: 0,
      transformOrigin: '50% 50%',
      duration: 1.6,
      stagger: { amount: 0.9, from: 'random' },
    }, 0);
    tl.from(off, { opacity: 0, duration: 1.2, stagger: { amount: 0.6, from: 'random' }, ease: 'power2.out' }, 0.5);
  }
  tl.from('[data-hero-in]', { y: 26, opacity: 0, duration: 1, stagger: 0.09, ease: 'power3.out' }, 0.75);
}

function noteWords() {
  const body = document.querySelector<HTMLElement>('[data-words]');
  if (!body) return;
  const split = SplitText.create(body, { type: 'words' });
  gsap.fromTo(split.words, { opacity: 0.14 }, {
    opacity: 1, stagger: 0.05, ease: 'none',
    scrollTrigger: { trigger: body, start: 'top 82%', end: 'bottom 55%', scrub: 0.5 },
  });
  gsap.from('[data-todo]', {
    x: -24, opacity: 0, stagger: 0.12, duration: 0.7, ease: 'power3.out',
    scrollTrigger: { trigger: '[data-todo]', start: 'top 88%' },
  });
}

function titles() {
  document.querySelectorAll<HTMLElement>('[data-split]').forEach((el) => {
    SplitText.create(el, {
      type: 'lines',
      mask: 'lines',
      autoSplit: true,
      onSplit: (self) =>
        gsap.from(self.lines, {
          yPercent: 105, duration: 1.05, stagger: 0.08, ease: 'expo.out',
          scrollTrigger: { trigger: el, start: 'top 86%', once: true },
        }),
    });
  });
}

function why() {
  const sec = document.querySelector<HTMLElement>('[data-why]');
  if (!sec) return;
  const problems = sec.querySelectorAll('[data-why-problem]');
  const answers = sec.querySelectorAll('[data-why-answer]');
  const strikes = sec.querySelectorAll('.why-strike path');
  // Off-screen positions are functions and re-measured on every refresh
  // (invalidateOnRefresh): measured once, a window that grows after loading
  // would start the answer cards in the middle of the problem cards.
  const offRight = () => innerWidth * 1.15;
  const tl = gsap.timeline({
    defaults: { ease: 'power3.out' },
    scrollTrigger: {
      trigger: sec, start: 'top top', end: () => `+=${innerHeight * 3}`,
      pin: sec.querySelector('.why-stage'), scrub: 0.7, anticipatePin: 1, invalidateOnRefresh: true,
    },
  });
  problems.forEach((card, i) =>
    tl.fromTo(card, { x: offRight, rotate: 7 }, { x: 0, rotate: (i - 1) * 1.6, duration: 1, immediateRender: true }, i * 0.55));
  answers.forEach((card) => tl.set(card, { x: offRight, rotate: 5 }, 0));
  strikes.forEach((path, i) => tl.to(path, { strokeDashoffset: 0, duration: 0.5, ease: 'power2.inOut' }, 1.9 + i * 0.25));
  // all three problems leave before the first answer comes in
  tl.to(problems, { x: () => -innerWidth * 1.25, rotate: -10, duration: 0.9, stagger: 0.1, ease: 'power3.in' }, 3.1);
  tl.to('[data-why-lead]', { opacity: 0, y: -30, duration: 0.6 }, 3.2);
  tl.fromTo('[data-why-turn]', { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.8 }, 4.0);
  answers.forEach((card, i) => tl.fromTo(card, { x: offRight, rotate: 5 }, { x: 0, rotate: 0, duration: 1, immediateRender: false }, 4.35 + i * 0.4));
  tl.to({}, { duration: 0.8 });
}

/** Panel blocks and the release strip: the stage stays, the track slides. */
function hscroll(selector: string) {
  document.querySelectorAll<HTMLElement>(selector).forEach((sec) => {
    const stage = sec.querySelector<HTMLElement>('[data-hscroll-stage]')!;
    const track = sec.querySelector<HTMLElement>('[data-hscroll-track]')!;
    const dist = () => Math.max(0, track.scrollWidth - innerWidth);
    gsap.fromTo(track, { x: () => (narrow() ? 0 : innerWidth * 0.18) }, {
      x: () => -dist(),
      ease: 'none',
      scrollTrigger: { trigger: sec, start: 'top top', end: () => `+=${dist() + innerHeight * 0.4}`, pin: stage, scrub: 0.6, invalidateOnRefresh: true, anticipatePin: 1 },
    });
  });
}

/** The eight clocks on an arc, turning while pinned (the A24 disc idea). */
function clocks() {
  const sec = document.querySelector<HTMLElement>('[data-clocks]');
  if (!sec) return;
  const cards = [...sec.querySelectorAll<HTMLElement>('[data-arc-card]')];
  const nameEl = sec.querySelector<HTMLElement>('[data-arc-name]')!;
  const names = cards.map((c) => c.querySelector('figcaption')!.textContent ?? '');
  let shownName = -1;

  const head = sec.querySelector<HTMLElement>('[data-arc-head]')!;
  const arc = sec.querySelector<HTMLElement>('[data-arc]')!;
  const layout = (p: number) => {
    // the cards take whatever height is left under the heading
    const top = head.offsetTop + head.offsetHeight + 28;
    const cw = Math.max(96, Math.min(220, (innerHeight - top - 20) / 2.7, innerWidth * 0.2));
    arc.style.setProperty('--cw', `${cw}px`);
    const R = Math.max(780, innerWidth * 0.95);
    const step = (cw * 1.32) / R; // radians between cards
    const span = (cards.length - 1) * step;
    let active = 0;
    let bestAbs = Infinity;
    cards.forEach((card, i) => {
      const a = i * step - p * span;
      const x = Math.sin(a) * R;
      const y = (1 - Math.cos(a)) * R;
      const near = Math.max(0, 1 - Math.abs(a) / (step * 2.2));
      card.style.transform = `translate(calc(-50% + ${x}px), ${top + y}px) rotate(${a}rad) scale(${0.82 + near * 0.26})`;
      card.style.zIndex = String(100 - Math.round(Math.abs(a) * 50));
      card.style.opacity = String(Math.abs(a) > Math.PI / 2 ? 0 : 1);
      if (Math.abs(a) < bestAbs) { bestAbs = Math.abs(a); active = i; }
    });
    if (active !== shownName) {
      shownName = active;
      nameEl.textContent = names[active];
      gsap.fromTo(nameEl, { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 0.45, ease: 'power3.out' });
    }
  };
  layout(0);
  ScrollTrigger.create({
    trigger: sec,
    start: 'top top',
    end: () => `+=${innerHeight * 2.4}`,
    pin: sec.querySelector('.clk-stage'),
    scrub: true,
    anticipatePin: 1,
    onUpdate: (self) => layout(self.progress),
    onRefresh: (self) => layout(self.progress),
  });
}

/** The download buttons start the download and then take you down to the
 *  steps, with the first one ticked off - so the next thing to do is right
 *  there instead of somewhere further down the page. */
function downloadThenGuide() {
  const steps = document.querySelector<HTMLElement>('[data-dl-steps]');
  if (!steps) return;
  document.querySelectorAll<HTMLAnchorElement>('[data-apk-link]').forEach((a) => {
    if (a.closest('#download')) return; // already there
    a.addEventListener('click', () => {
      // the link itself downloads (GitHub serves the APK as an attachment,
      // so the page stays); the scroll follows a moment later
      steps.classList.add('is-started');
      setTimeout(() => goTo('download'), 250);
    });
  });
  document.querySelectorAll<HTMLAnchorElement>('#download [data-apk-link]').forEach((a) =>
    a.addEventListener('click', () => steps.classList.add('is-started')));
}

/** The clip cards in "the rest" drift a little against the scroll. */
function stream() {
  document.querySelectorAll<HTMLElement>('[data-drift]').forEach((el) => {
    gsap.fromTo(el, { y: Number(el.dataset.drift) * 6 }, {
      y: Number(el.dataset.drift) * -6, ease: 'none',
      scrollTrigger: { trigger: el, start: 'top bottom', end: 'bottom top', scrub: true },
    });
  });
}

/** The night opens from a rounded window to the full screen as it arrives. */
function night() {
  const el = document.querySelector<HTMLElement>('[data-night]');
  if (!el) return;
  gsap.fromTo(el, { clipPath: 'inset(14% 12% 14% 12% round 48px)' }, {
    clipPath: 'inset(0% 0% 0% 0% round 0px)', ease: 'none',
    scrollTrigger: { trigger: el, start: 'top bottom', end: 'top top', scrub: true },
  });
  ScrollTrigger.create({
    trigger: el, start: 'top 40%', end: 'bottom 40%',
    onToggle: (self) => root.classList.toggle('in-night', self.isActive),
  });
}

/** Stars like the trailer's opening; drawn only while the night is visible. */
function stars() {
  const canvas = document.querySelector<HTMLCanvasElement>('[data-stars]');
  if (!canvas) return;
  const ctx = canvas.getContext('2d')!;
  let pts: { x: number; y: number; r: number; p: number; v: number }[] = [];
  let visible = false;
  const size = () => {
    const dpr = Math.min(devicePixelRatio, 2);
    canvas.width = canvas.clientWidth * dpr;
    canvas.height = canvas.clientHeight * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const n = Math.round((canvas.clientWidth * canvas.clientHeight) / 5200);
    pts = Array.from({ length: n }, () => ({
      x: Math.random() * canvas.clientWidth,
      y: Math.random() * canvas.clientHeight,
      r: Math.random() < 0.08 ? 1.6 : Math.random() * 1.1 + 0.3,
      p: Math.random() * Math.PI * 2,
      v: Math.random() * 0.12 + 0.03,
    }));
  };
  const draw = (t: number) => {
    if (!visible) return;
    ctx.clearRect(0, 0, canvas.clientWidth, canvas.clientHeight);
    const H = canvas.clientHeight;
    for (const s of pts) {
      ctx.globalAlpha = motion ? 0.35 + 0.65 * Math.abs(Math.sin(s.p + t * 0.0048 * s.v)) : 0.8;
      ctx.fillStyle = s.r > 1.4 ? '#bfe6ff' : '#e8ebff';
      // a slow upward drift, wrapping round
      const y = motion ? (((s.y - t * s.v * 0.01) % H) + H) % H : s.y;
      ctx.beginPath();
      ctx.arc(s.x, y, s.r, 0, Math.PI * 2);
      ctx.fill();
    }
    if (motion) requestAnimationFrame(draw);
  };
  new ResizeObserver(size).observe(canvas);
  new IntersectionObserver(([e]) => {
    const was = visible;
    visible = e.isIntersecting;
    if (visible && !was) requestAnimationFrame(draw);
  }).observe(canvas);
}

/** The three steps beside the letter-bar clip light up while it does them. */
function alphabetSteps() {
  const list = document.querySelector<HTMLElement>('[data-steps]');
  if (!list) return;
  const steps = [...list.querySelectorAll<HTMLElement>('li')];
  const v = getClip(list.dataset.steps!);
  v.addEventListener('timeupdate', () => {
    steps.forEach((li) => {
      const on = v.currentTime >= Number(li.dataset.from) && v.currentTime < Number(li.dataset.to);
      li.classList.toggle('is-now', on);
    });
  });
}

/** The 3D phone, once the page has settled; the CSS phones stand in until
 *  then, and for good if WebGL is missing or motion is reduced. */
function startStage() {
  const canvas = document.querySelector<HTMLCanvasElement>('[data-stage]');
  const gl = (() => {
    try {
      const c = document.createElement('canvas');
      return !!(c.getContext('webgl2') || c.getContext('webgl'));
    } catch {
      return false;
    }
  })();
  const saveData = (navigator as any).connection?.saveData === true;
  if (!canvas || !gl || !motion || saveData) {
    fallbackSlots();
    return;
  }
  const go = () =>
    import('./stage')
      .then(({ startStage }) => startStage(canvas))
      .then(() => root.classList.add('gl-ready'))
      .catch((e) => {
        console.warn('3D phone unavailable:', e);
        fallbackSlots();
      });
  const idle = (window as any).requestIdleCallback ?? ((f: () => void) => setTimeout(f, 300));
  if (document.readyState === 'complete') idle(go);
  else addEventListener('load', () => idle(go), { once: true });
}
