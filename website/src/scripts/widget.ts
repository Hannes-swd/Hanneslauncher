// The draggable widget card. Elements move in percent of the card, so the
// layout survives any resize; while dragging, an element snaps to the
// card's centre lines and to the other elements' edges within a few
// pixels, and the guide it snapped to is drawn - like the app's editor.

const SNAP = 6; // px

/** The first time the card is on screen, a touch dot - the one Android
 *  draws in the recordings - presses one piece, slides it aside and back,
 *  so nobody has to guess that the card can be edited. Touching the card
 *  yourself stops it. */
export function showOnce(card: HTMLElement, target: HTMLElement | null) {
  if (!target || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  const io = new IntersectionObserver(async ([e]) => {
    if (!e.isIntersecting) return;
    io.disconnect();
    const dot = document.createElement('span');
    dot.className = 'ghost-dot';
    card.append(dot);
    const anims: Animation[] = [];
    let stopped = false;
    const stop = () => {
      stopped = true;
      anims.forEach((a) => a.cancel());
      target.classList.remove('is-dragging');
      dot.remove();
    };
    card.addEventListener('pointerdown', stop, { once: true });
    const run = (el: HTMLElement, kf: Keyframe[], ms: number, delay = 0) => {
      const a = el.animate(kf, { duration: ms, delay, easing: 'cubic-bezier(.65,0,.35,1)', fill: 'forwards' });
      anims.push(a);
      return a.finished;
    };
    const cr = card.getBoundingClientRect();
    const tr = target.getBoundingClientRect();
    const tx = tr.left - cr.left + tr.width / 2 - 18;
    const ty = tr.top - cr.top + tr.height / 2 - 18;
    const dx = -cr.width * 0.24;
    try {
      await new Promise((r) => setTimeout(r, 700));
      if (stopped) return;
      await run(dot, [
        { transform: `translate(${cr.width}px, ${cr.height}px) scale(1)`, opacity: 0 },
        { transform: `translate(${tx}px, ${ty}px) scale(1)`, opacity: 1 },
      ], 800);
      await run(dot, [{ transform: `translate(${tx}px, ${ty}px) scale(1)` }, { transform: `translate(${tx}px, ${ty}px) scale(0.78)` }], 160);
      target.classList.add('is-dragging');
      await Promise.all([
        run(dot, [{ transform: `translate(${tx}px, ${ty}px) scale(0.78)` }, { transform: `translate(${tx + dx}px, ${ty}px) scale(0.78)` }], 900),
        run(target, [{ transform: 'translate(0, 0)' }, { transform: `translate(${dx}px, 0)` }], 900),
      ]);
      await new Promise((r) => setTimeout(r, 350));
      await Promise.all([
        run(dot, [{ transform: `translate(${tx + dx}px, ${ty}px) scale(0.78)` }, { transform: `translate(${tx}px, ${ty}px) scale(0.78)` }], 750),
        run(target, [{ transform: `translate(${dx}px, 0)` }, { transform: 'translate(0, 0)' }], 750),
      ]);
      target.classList.remove('is-dragging');
      await run(dot, [{ transform: `translate(${tx}px, ${ty}px) scale(0.78)`, opacity: 1 }, { transform: `translate(${tx}px, ${ty}px) scale(1.3)`, opacity: 0 }], 350);
      stop();
    } catch {
      /* cancelled by a real touch */
    }
  }, { threshold: 0.7 });
  io.observe(card);
}

export function initWidget() {
  const card = document.querySelector<HTMLElement>('[data-widget]');
  if (!card) return;
  const gx = card.querySelector<HTMLElement>('[data-guide-x]')!;
  const gy = card.querySelector<HTMLElement>('[data-guide-y]')!;
  const els = [...card.querySelectorAll<HTMLElement>('[data-el]')];

  // placeholders: the same names the launcher uses, filled the way it would
  const lang = document.documentElement.lang;
  const fill = () => {
    const now = new Date();
    card.querySelectorAll<HTMLElement>('[data-ph]').forEach((el) => {
      if (el.dataset.ph === 'zeit')
        el.textContent = now.toLocaleTimeString(lang, { hour: '2-digit', minute: '2-digit' });
      if (el.dataset.ph === 'wochentag')
        el.textContent = now.toLocaleDateString(lang, { weekday: 'long' });
    });
  };
  fill();
  setInterval(fill, 15_000);

  showOnce(card, card.querySelector<HTMLElement>('.el-icon'));

  els.forEach((el) => {
    let sx = 0, sy = 0, ox = 0, oy = 0;
    el.addEventListener('pointerdown', (e) => {
      const cr = card.getBoundingClientRect();
      const er = el.getBoundingClientRect();
      sx = e.clientX; sy = e.clientY;
      ox = er.left - cr.left; oy = er.top - cr.top;
      el.setPointerCapture(e.pointerId);
      el.classList.add('is-dragging');
      el.style.zIndex = '3';
      e.preventDefault();
    });
    el.addEventListener('pointermove', (e) => {
      if (!el.hasPointerCapture(e.pointerId)) return;
      const cr = card.getBoundingClientRect();
      const er = el.getBoundingClientRect();
      let x = ox + e.clientX - sx;
      let y = oy + e.clientY - sy;
      x = Math.max(0, Math.min(cr.width - er.width, x));
      y = Math.max(0, Math.min(cr.height - er.height, y));

      // candidate lines: card centre, other elements' edges and centres
      const xs = [cr.width / 2];
      const ys = [cr.height / 2];
      els.forEach((o) => {
        if (o === el) return;
        const r = o.getBoundingClientRect();
        xs.push(r.left - cr.left, r.left - cr.left + r.width / 2);
        ys.push(r.top - cr.top, r.top - cr.top + r.height / 2, r.bottom - cr.top);
      });
      let hitX: number | null = null;
      let hitY: number | null = null;
      for (const lx of xs) {
        for (const [edge, off] of [[x, 0], [x + er.width / 2, er.width / 2]] as const) {
          if (hitX === null && Math.abs(edge - lx) < SNAP) { x = lx - off; hitX = lx; }
        }
      }
      for (const ly of ys) {
        for (const [edge, off] of [[y, 0], [y + er.height / 2, er.height / 2], [y + er.height, er.height]] as const) {
          if (hitY === null && Math.abs(edge - ly) < SNAP) { y = ly - off; hitY = ly; }
        }
      }
      gx.hidden = hitX === null;
      gy.hidden = hitY === null;
      if (hitX !== null) gx.style.left = `${hitX}px`;
      if (hitY !== null) gy.style.top = `${hitY}px`;
      el.style.setProperty('--x', `${(x / cr.width) * 100}%`);
      el.style.setProperty('--y', `${(y / cr.height) * 100}%`);
    });
    const end = () => {
      el.classList.remove('is-dragging');
      el.style.zIndex = '';
      gx.hidden = true;
      gy.hidden = true;
    };
    el.addEventListener('pointerup', end);
    el.addEventListener('pointercancel', end);
  });
}
