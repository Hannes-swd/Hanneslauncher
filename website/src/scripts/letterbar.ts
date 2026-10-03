// The letter bar, behaving like the launcher's (lib/app_list_view.dart):
// scrubbing up and down picks a letter and reveals its entries at the top
// left; past a threshold to the left the letter locks and the finger's
// height picks a row instead; letting go opens it. The letters swell
// around the finger and bend towards it into an arc while picking a row.
import { goTo } from './nav';

type Target = { id: string; label: string };

const TARGET_THRESHOLD = 44; // px left of the bar before rows are picked
const SWELL_SIGMA = 30; // how far the magnification reaches, px
const ARC_SIGMA = 120; // how far the bend reaches, px

export function initLetterBar() {
  const bar = document.querySelector<HTMLElement>('[data-letterbar]');
  if (!bar) return;
  const buttons = [...bar.querySelectorAll<HTMLButtonElement>('[data-letter]')];
  const veil = document.querySelector<HTMLElement>('[data-veil]')!;
  const head = veil.querySelector<HTMLElement>('[data-veil-head]')!;
  const rows = veil.querySelector<HTMLOListElement>('[data-veil-rows]')!;
  const bubble = document.querySelector<HTMLElement>('[data-bubble]')!;
  const targetsOf = (b: HTMLButtonElement): Target[] => JSON.parse(b.dataset.targets || '[]');

  let scrubbing = false;
  let letter: HTMLButtonElement | null = null;
  let targeting = false;
  let row = -1;
  let moved = false;

  const centers = () => buttons.map((b) => {
    const r = b.getBoundingClientRect();
    return r.top + r.height / 2;
  });

  function shape(y: number | null, dx = 0) {
    const cs = centers();
    buttons.forEach((b, i) => {
      if (y === null) {
        b.style.transform = '';
        return;
      }
      const d = cs[i] - y;
      const g = Math.exp(-(d * d) / (2 * SWELL_SIGMA * SWELL_SIGMA));
      const arc = targeting ? Math.exp(-(d * d) / (2 * ARC_SIGMA * ARC_SIGMA)) * Math.max(0, dx - 10) : 0;
      b.style.transform = `translateX(${-(g * 16 + arc)}px) scale(${1 + g * 0.9})`;
    });
  }

  function nearest(y: number) {
    const cs = centers();
    let best = 0;
    cs.forEach((c, i) => {
      if (Math.abs(c - y) < Math.abs(cs[best] - y)) best = i;
    });
    return buttons[best];
  }

  function showLetter(b: HTMLButtonElement) {
    if (b === letter) return;
    letter = b;
    head.textContent = b.dataset.letter || '';
    rows.replaceChildren(...targetsOf(b).map((t) => {
      const li = document.createElement('li');
      li.textContent = t.label;
      return li;
    }));
    bubble.textContent = b.dataset.letter || '';
  }

  function pickRow(y: number) {
    const items = [...rows.children] as HTMLElement[];
    let next = -1;
    items.forEach((li, i) => {
      const r = li.getBoundingClientRect();
      if (y >= r.top - 6 && y <= r.bottom + 6) next = i;
    });
    if (next !== row) {
      items.forEach((li, i) => li.classList.toggle('is-target', i === next));
      row = next;
    }
  }

  function start(e: PointerEvent) {
    if (e.button !== 0) return;
    const onSearch = (e.target as HTMLElement).closest('[data-open-search]');
    if (onSearch) return;
    scrubbing = true;
    moved = false;
    targeting = false;
    row = -1;
    letter = null;
    try { bar.setPointerCapture(e.pointerId); } catch { /* pointer already gone */ }
    move(e);
    veil.classList.add('is-open');
    bubble.classList.add('is-open');
    e.preventDefault();
  }

  function move(e: PointerEvent) {
    const barLeft = bar.getBoundingClientRect().left;
    const dx = barLeft - e.clientX;
    if (!scrubbing) {
      // a mouse just passing over: swell only
      if (e.pointerType === 'mouse') shape(e.clientY);
      return;
    }
    moved = true;
    const wasTargeting = targeting;
    targeting = dx >= TARGET_THRESHOLD;
    if (!targeting) {
      showLetter(nearest(e.clientY));
      if (wasTargeting) pickRow(-1);
    } else {
      pickRow(e.clientY);
    }
    bubble.style.top = `${e.clientY}px`;
    bubble.style.right = `${Math.max(0, dx) + 78}px`;
    shape(e.clientY, dx);
  }

  function end(e: PointerEvent) {
    if (!scrubbing) return;
    scrubbing = false;
    veil.classList.remove('is-open');
    bubble.classList.remove('is-open');
    shape(null);
    const chosen = letter ? targetsOf(letter) : [];
    const pick = targeting ? chosen[row] : chosen[0];
    letter = null;
    rows.querySelectorAll('.is-target').forEach((li) => li.classList.remove('is-target'));
    if (e.type === 'pointerup' && pick && (moved || !targeting)) goTo(pick.id);
  }

  bar.addEventListener('pointerdown', start);
  bar.addEventListener('pointermove', move);
  bar.addEventListener('pointerup', end);
  bar.addEventListener('pointercancel', end);
  bar.addEventListener('pointerleave', (e) => {
    if (!scrubbing && e.pointerType === 'mouse') shape(null);
  });
  // keyboard: a letter is a button that opens its first chapter
  buttons.forEach((b) =>
    b.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        const first = targetsOf(b)[0];
        if (first) goTo(first.id);
      }
    }),
  );

  // Which chapter is on screen lights its letter, like the launcher's
  // active letter.
  const byId = new Map<string, HTMLButtonElement>();
  buttons.forEach((b) => targetsOf(b).forEach((t) => byId.set(t.id, b)));
  const io = new IntersectionObserver(
    (entries) => {
      for (const en of entries) {
        if (!en.isIntersecting) continue;
        buttons.forEach((b) => b.classList.remove('is-on'));
        byId.get(en.target.id)?.classList.add('is-on');
      }
    },
    { rootMargin: '-45% 0px -50% 0px' },
  );
  byId.forEach((_, id) => {
    const el = document.getElementById(id);
    if (el) io.observe(el);
  });

  initSearch();
}

// ---- search: the magnifier at the bottom of the bar -----------------------

type Item = { label: string; id: string };

/** Ranks like the launcher's search: whole name, then start of the name,
 *  then start of a word, then letters in order ("ytm" -> YouTube Music). */
function score(label: string, q: string): number {
  const l = label.toLowerCase();
  if (!q) return 0;
  if (l === q) return 100;
  if (l.startsWith(q)) return 90;
  if (l.split(/[\s\-–·]+/).some((w) => w.startsWith(q))) return 75;
  if (l.includes(q)) return 55;
  let i = 0;
  let starts = 0;
  for (let k = 0; k < l.length && i < q.length; k++) {
    if (l[k] === q[i]) {
      if (k === 0 || /[\s\-]/.test(l[k - 1])) starts++;
      i++;
    }
  }
  return i === q.length ? 30 + starts * 5 : 0;
}

/** Sums, the way the launcher's search answers them. A tiny parser, no eval. */
export function calc(src: string): number | null {
  const s = src.replace(/×/g, '*').replace(/÷/g, '/').replace(/,/g, '.').replace(/\s+/g, '');
  if (!/^[\d.+\-*/()^%]+$/.test(s) || !/[+\-*/^%]/.test(s.slice(1))) return null;
  let p = 0;
  const peek = () => s[p];
  const num = (): number => {
    if (peek() === '(') {
      p++;
      const v = expr();
      if (peek() !== ')') throw 0;
      p++;
      return v;
    }
    if (peek() === '-') { p++; return -num(); }
    const m = /^\d*\.?\d+/.exec(s.slice(p));
    if (!m) throw 0;
    p += m[0].length;
    let v = parseFloat(m[0]);
    if (peek() === '%') { p++; v /= 100; }
    return v;
  };
  const pow = (): number => {
    const b = num();
    if (peek() === '^') { p++; return Math.pow(b, pow()); }
    return b;
  };
  const term = (): number => {
    let v = pow();
    while (peek() === '*' || peek() === '/') v = s[p++] === '*' ? v * pow() : v / pow();
    return v;
  };
  const expr = (): number => {
    let v = term();
    while (peek() === '+' || peek() === '-') v = s[p++] === '+' ? v + term() : v - term();
    return v;
  };
  try {
    const v = expr();
    return p === s.length && Number.isFinite(v) ? Math.round(v * 1e10) / 1e10 : null;
  } catch {
    return null;
  }
}

function initSearch() {
  const box = document.querySelector<HTMLElement>('[data-search]');
  if (!box) return;
  const input = box.querySelector<HTMLInputElement>('[data-search-input]')!;
  const list = box.querySelector<HTMLOListElement>('[data-search-results]')!;
  const items: Item[] = JSON.parse(document.querySelector('[data-search-items]')!.textContent || '[]');
  const lang = document.documentElement.lang;

  const open = () => {
    box.hidden = false;
    input.value = '';
    render();
    input.focus();
  };
  const close = () => {
    box.hidden = true;
  };

  function render() {
    const q = input.value.trim().toLowerCase();
    const out: HTMLElement[] = [];
    const sum = calc(q);
    if (sum !== null) {
      const li = document.createElement('li');
      li.innerHTML = `<button type="button" class="is-first"><span class="sum"></span><small>${q}</small></button>`;
      li.querySelector('.sum')!.textContent = sum.toLocaleString(lang);
      out.push(li);
    }
    const seen = new Set<string>();
    items
      .map((it) => ({ it, s: score(it.label, q) }))
      .filter((r) => r.s > 0 && !seen.has(r.it.label) && seen.add(r.it.label))
      .sort((a, b) => b.s - a.s)
      .slice(0, 7)
      .forEach(({ it }, i) => {
        const li = document.createElement('li');
        const b = document.createElement('button');
        b.type = 'button';
        b.textContent = it.label;
        if (i === 0 && sum === null) b.classList.add('is-first');
        b.addEventListener('click', () => {
          close();
          goTo(it.id);
        });
        li.append(b);
        out.push(li);
      });
    list.replaceChildren(...out);
  }

  input.addEventListener('input', render);
  input.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') close();
    if (e.key === 'Enter') (list.querySelector('button.is-first') as HTMLButtonElement | null)?.click();
  });
  box.querySelector('[data-search-close]')!.addEventListener('click', close);
  box.addEventListener('click', (e) => {
    if (e.target === box) close();
  });
  document.querySelectorAll('[data-open-search]').forEach((b) => b.addEventListener('click', open));
}
