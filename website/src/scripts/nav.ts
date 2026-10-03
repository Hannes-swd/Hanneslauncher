// One way to move through the page, so the letter bar, the search and the
// menu all scroll the same smooth way (Lenis when it runs, native otherwise).

type Scroller = { scrollTo: (target: HTMLElement | number, opts?: Record<string, unknown>) => void };
let scroller: Scroller | null = null;

export const setScroller = (s: Scroller | null) => (scroller = s);

export function goTo(id: string) {
  const el = document.getElementById(id);
  if (!el) return;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
  if (scroller && !reduced) scroller.scrollTo(el, { offset: 0, duration: 1.4 });
  else el.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth' });
  history.replaceState(null, '', `#${id}`);
  // keyboard users land where they jumped to
  el.setAttribute('tabindex', '-1');
  el.focus({ preventScroll: true });
}
