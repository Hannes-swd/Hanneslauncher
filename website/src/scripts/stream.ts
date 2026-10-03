// The bubble rows in "and then there's the rest": each drifts on its own,
// can be grabbed and flung sideways, and wraps round without end. A row
// holds its items three times over; its position is kept modulo one set's
// width, so whichever way it travels there is always more coming.

type Row = {
  el: HTMLElement;
  offset: number;
  velocity: number; // px/s from a fling, decays
  drift: number; // px/s on its own
  setW: number;
  dragging: boolean;
};

export function initStream() {
  const box = document.querySelector<HTMLElement>('[data-stream-box]');
  if (!box) return;
  box.classList.add('is-live');
  const still = matchMedia('(prefers-reduced-motion: reduce)').matches;

  const rows: Row[] = [...box.querySelectorAll<HTMLElement>('[data-stream]')].map((el, i) => {
    const speed = Number(getComputedStyle(el).getPropertyValue('--speed')) || 1;
    const dir = el.dataset.stream === 'left' ? 1 : -1;
    return { el, offset: i * 137, velocity: 0, drift: still ? 0 : 22 * speed * dir, setW: 1, dragging: false };
  });
  const measure = () => rows.forEach((r) => (r.setW = Math.max(1, r.el.scrollWidth / 3)));
  measure();
  new ResizeObserver(measure).observe(box);

  // a scroll of the page nudges the rows along a little
  let lastScroll = scrollY;
  addEventListener('scroll', () => {
    const d = scrollY - lastScroll;
    lastScroll = scrollY;
    rows.forEach((r) => { if (!r.dragging) r.offset += d * 0.25 * Math.sign(r.drift || 1); });
  }, { passive: true });

  rows.forEach((r) => {
    let lastX = 0;
    let lastT = 0;
    r.el.addEventListener('pointerdown', (e) => {
      if (e.button !== 0) return;
      r.dragging = true;
      r.velocity = 0;
      lastX = e.clientX;
      lastT = performance.now();
      try { r.el.setPointerCapture(e.pointerId); } catch { /* gone already */ }
      r.el.classList.add('is-grabbed');
    });
    r.el.addEventListener('pointermove', (e) => {
      if (!r.dragging) return;
      const now = performance.now();
      const dx = e.clientX - lastX;
      const dt = Math.max(1, now - lastT) / 1000;
      r.offset -= dx;
      // smoothed, so the fling follows the last moments of the drag
      r.velocity = r.velocity * 0.6 + (-dx / dt) * 0.4;
      lastX = e.clientX;
      lastT = now;
    });
    const end = () => {
      if (!r.dragging) return;
      r.dragging = false;
      r.el.classList.remove('is-grabbed');
      if (performance.now() - lastT > 90) r.velocity = 0; // held still before letting go
    };
    r.el.addEventListener('pointerup', end);
    r.el.addEventListener('pointercancel', end);
  });

  let visible = false;
  let last = performance.now();
  const frame = (now: number) => {
    if (!visible) return;
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    for (const r of rows) {
      if (!r.dragging) {
        r.offset += (r.drift + r.velocity) * dt;
        r.velocity *= Math.pow(0.04, dt); // friction: most of a fling is gone in a second
      }
      const x = ((r.offset % r.setW) + r.setW) % r.setW;
      r.el.style.transform = `translate3d(${-x}px, 0, 0)`;
    }
    requestAnimationFrame(frame);
  };
  new IntersectionObserver(([e]) => {
    const was = visible;
    visible = e.isIntersecting;
    if (visible && !was) {
      last = performance.now();
      requestAnimationFrame(frame);
    }
  }).observe(box);
}
