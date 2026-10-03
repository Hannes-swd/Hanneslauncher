// The Design chapter's controls write the page's custom properties. The
// bounds come from the inputs (4..32 px, 0..1 shadows), which are the app's
// own (radiusRange, shadowRange in lib/design_tokens.dart).

type Theme = { ground: string; card: string; ink: string; ink2: string; accent: string; line: string };

export function initDesign() {
  const box = document.querySelector<HTMLElement>('[data-design]');
  if (!box) return;
  const root = document.documentElement;
  const radios = [...box.querySelectorAll<HTMLInputElement>('input[name="theme"]')];
  const r = box.querySelector<HTMLInputElement>('[data-range="r"]')!;
  const sh = box.querySelector<HTMLInputElement>('[data-range="sh"]')!;
  const outR = box.querySelector<HTMLOutputElement>('[data-out="r"]')!;
  const outSh = box.querySelector<HTMLOutputElement>('[data-out="sh"]')!;

  const setTheme = (th: Theme | null, dark = false) => {
    const props: [string, string | null][] = [
      ['--paper', th?.ground ?? null],
      ['--card', th?.card ?? null],
      ['--ink', th?.ink ?? null],
      ['--ink-2', th?.ink2 ?? null],
      ['--line', th?.line ?? null],
      ['--accent', th?.accent ?? null],
      // amber on near-black wants dark text on its buttons, like the app's
      // contrast rule for text on accent
      ['--on-accent', dark ? '#1b1a17' : null],
      // the same alpha over near-black is invisible, so shadows deepen x1.7
      ['--depth', dark ? '1.7' : null],
    ];
    for (const [k, v] of props) v === null ? root.style.removeProperty(k) : root.style.setProperty(k, v);
    root.classList.toggle('theme-dark', dark);
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', th?.ground ?? '#f4f3f0');
  };

  radios.forEach((radio) =>
    radio.addEventListener('change', () => {
      if (radio.checked) setTheme(JSON.parse(radio.dataset.theme!), radio.value === 'dark');
    }),
  );
  r.addEventListener('input', () => {
    root.style.setProperty('--r', `${r.value}px`);
    outR.textContent = `${r.value} px`;
  });
  sh.addEventListener('input', () => {
    root.style.setProperty('--sh', String(Number(sh.value) * 2));
    outSh.textContent = `${Math.round(Number(sh.value) * 100)} %`;
  });
  box.querySelector('[data-design-reset]')!.addEventListener('click', () => {
    radios.forEach((x) => (x.checked = false));
    setTheme(null);
    r.value = '24';
    sh.value = '0.5';
    root.style.removeProperty('--r');
    root.style.removeProperty('--sh');
    outR.textContent = '24 px';
    outSh.textContent = '50 %';
  });
}
