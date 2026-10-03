// What the visitor allowed, kept only in their own browser. Two switches,
// both off until switched on: "media" (the YouTube trailer) and "stats"
// (Vercel Web Analytics). Nothing else on the page needs consent - fonts,
// pictures, clips and the release list all come from this site itself.

export type Consent = { media: boolean; stats: boolean };
const KEY = 'hl-consent-v1';
let state: Consent | null = null;

function read(): Consent | null {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return null;
    const v = JSON.parse(raw);
    return { media: !!v.media, stats: !!v.stats };
  } catch {
    return null;
  }
}

function write(c: Consent) {
  state = c;
  try {
    localStorage.setItem(KEY, JSON.stringify({ ...c, at: new Date().toISOString() }));
  } catch {
    /* private mode: the choice holds for this visit only */
  }
  apply(c);
  window.dispatchEvent(new CustomEvent<Consent>('hl:consent', { detail: c }));
}

let analyticsOn = false;
async function apply(c: Consent) {
  if (c.stats && !analyticsOn) {
    analyticsOn = true;
    const { inject } = await import('@vercel/analytics');
    inject({ mode: import.meta.env.PROD ? 'production' : 'development' });
  }
}

export const getConsent = (): Consent => state ?? read() ?? { media: false, stats: false };

/** Switches one category on, e.g. when someone clicks "play" on the trailer. */
export function allow(key: keyof Consent) {
  write({ ...getConsent(), [key]: true });
}

export function initConsent() {
  const box = document.querySelector<HTMLElement>('[data-consent]');
  if (!box) return;
  const choices = box.querySelector<HTMLElement>('[data-consent-choices]')!;
  const choose = box.querySelector<HTMLButtonElement>('[data-consent-choose]')!;
  const save = box.querySelector<HTMLButtonElement>('[data-consent-save]')!;
  const boxes = [...box.querySelectorAll<HTMLInputElement>('[data-consent-key]')];

  const open = () => {
    const c = getConsent();
    boxes.forEach((b) => (b.checked = c[b.dataset.consentKey as keyof Consent]));
    box.hidden = false;
  };
  const close = () => {
    box.hidden = true;
  };

  box.querySelector('[data-consent-all]')!.addEventListener('click', () => {
    write({ media: true, stats: true });
    close();
  });
  box.querySelector('[data-consent-none]')!.addEventListener('click', () => {
    write({ media: false, stats: false });
    close();
  });
  choose.addEventListener('click', () => {
    const show = choices.hidden;
    choices.hidden = !show;
    save.hidden = !show;
    choose.setAttribute('aria-expanded', String(show));
  });
  save.addEventListener('click', () => {
    const next = { media: false, stats: false };
    boxes.forEach((b) => (next[b.dataset.consentKey as keyof Consent] = b.checked));
    write(next);
    close();
  });
  document.addEventListener('click', (e) => {
    const target = (e.target as HTMLElement).closest('[data-consent-open]');
    if (target) {
      e.preventDefault();
      open();
    }
  });

  const stored = read();
  if (stored) {
    state = stored;
    apply(stored);
  } else {
    open();
  }
}
