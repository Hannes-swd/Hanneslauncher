// One design state for the whole page, the way the app has one theme for
// everything it draws. The controls in the design chapter and the light/dark
// switch in the top bar edit the same state; the choice is kept in the visitor's own
// browser so the next visit starts the same. The inline script in Base
// applies it before the first paint, this file takes over from there.

import { THEMES, DESIGN_KEY, DESIGN_DEFAULT, type DesignState, type ThemeId } from '../data/themes';

const root = document.documentElement;
let state: DesignState = load();
// the light look to return to from dark; null is the default look
let lastLight: ThemeId | null = state.theme === 'dark' ? null : state.theme;

function load(): DesignState {
  try {
    const v = JSON.parse(localStorage.getItem(DESIGN_KEY) || 'null');
    if (v && typeof v === 'object') return { ...DESIGN_DEFAULT, ...v };
  } catch { /* private mode */ }
  // nothing picked yet: follow the system's dark mode
  return { ...DESIGN_DEFAULT, theme: matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : null };
}

function save() {
  try { localStorage.setItem(DESIGN_KEY, JSON.stringify(state)); } catch { /* private mode */ }
}

export function applyDesign(s: DesignState) {
  const th = s.theme ? THEMES[s.theme] : null;
  const dark = s.theme === 'dark';
  const props: [string, string | null][] = [
    ['--paper', th?.ground ?? null],
    ['--card', th?.card ?? null],
    ['--ink', th?.ink ?? null],
    ['--ink-2', th?.ink2 ?? null],
    ['--line', th?.line ?? null],
    // no theme picked: the page keeps the logo's indigo as its accent
    ['--accent', th?.accent ?? null],
    // amber on near-black wants dark text on its buttons, like the app's
    // contrast rule for text on accent
    ['--on-accent', dark ? '#1b1a17' : null],
    // the same alpha over near-black is invisible, so shadows deepen x1.7
    ['--depth', dark ? '1.7' : null],
    ['--r', s.r !== DESIGN_DEFAULT.r ? `${s.r}px` : null],
    ['--sh', s.sh !== DESIGN_DEFAULT.sh ? String(s.sh * 2) : null],
  ];
  for (const [k, v] of props) (v === null ? root.style.removeProperty(k) : root.style.setProperty(k, v));
  root.classList.toggle('theme-dark', dark);
  document.querySelector('meta[name="theme-color"]')?.setAttribute('content', th?.ground ?? '#f4f3f0');
}

function sync() {
  document.querySelectorAll<HTMLElement>('[data-design]').forEach((box) => {
    box.querySelectorAll<HTMLInputElement>('input[type=radio]').forEach((r) => (r.checked = r.value === state.theme));
    const r = box.querySelector<HTMLInputElement>('[data-range="r"]')!;
    const sh = box.querySelector<HTMLInputElement>('[data-range="sh"]')!;
    r.value = String(state.r);
    sh.value = String(state.sh);
    box.querySelector('[data-out="r"]')!.textContent = `${state.r} px`;
    box.querySelector('[data-out="sh"]')!.textContent = `${Math.round(state.sh * 100)} %`;
  });
  document.querySelectorAll<HTMLButtonElement>('[data-dark-toggle]').forEach((b) =>
    b.setAttribute('aria-pressed', String(state.theme === 'dark')));
}

function set(next: Partial<DesignState>) {
  state = { ...state, ...next };
  if (state.theme !== 'dark') lastLight = state.theme;
  applyDesign(state);
  sync();
  save();
}

export function initDesign() {
  applyDesign(state);
  sync();
  // nothing picked by hand: follow the system's light/dark live, also when
  // it switches while the page is open (e.g. automatic dark at sunset)
  matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
    let picked = false;
    try { picked = !!localStorage.getItem(DESIGN_KEY); } catch { /* private mode */ }
    if (picked) return;
    state = { ...state, theme: e.matches ? 'dark' : null };
    applyDesign(state);
    sync();
  });
  document.querySelectorAll<HTMLElement>('[data-design]').forEach((box) => {
    box.querySelectorAll<HTMLInputElement>('input[type=radio]').forEach((radio) =>
      radio.addEventListener('change', () => radio.checked && set({ theme: radio.value as ThemeId })));
    box.querySelector<HTMLInputElement>('[data-range="r"]')!.addEventListener('input', (e) =>
      set({ r: Number((e.target as HTMLInputElement).value) }));
    box.querySelector<HTMLInputElement>('[data-range="sh"]')!.addEventListener('input', (e) =>
      set({ sh: Number((e.target as HTMLInputElement).value) }));
    box.querySelector('[data-design-reset]')!.addEventListener('click', () => set({ ...DESIGN_DEFAULT }));
  });

  // the moon in the top bar: dark and back to whichever light theme was last
  document.querySelectorAll<HTMLButtonElement>('[data-dark-toggle]').forEach((b) =>
    b.addEventListener('click', () => set({ theme: state.theme === 'dark' ? lastLight : 'dark' })));

}
