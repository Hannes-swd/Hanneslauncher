// The page is built with the releases of the day it was built. New
// launcher releases don't rebuild the site, so once the page has loaded it
// asks this site's own /api/release.json (never GitHub directly) and, if
// there is something newer, updates every version, size, download link and
// the release strip.

import { ScrollTrigger } from 'gsap/ScrollTrigger';

type Rel = { version: string; date: string; url: string; title: string; points: number; apk?: { url: string; size: number } };

export async function refreshReleases() {
  const sec = document.querySelector<HTMLElement>('[data-upd-i18n]');
  const i18n = sec ? JSON.parse(sec.dataset.updI18n!) : null;
  let data: { releases: Rel[]; total: number; first: string | null; partial?: boolean };
  try {
    const res = await fetch('/api/release.json', { headers: { Accept: 'application/json' } });
    if (!res.ok) return;
    data = await res.json();
  } catch {
    return;
  }
  const latest = data.releases?.[0];
  if (!latest || (i18n && i18n.baked === latest.version)) return;

  document.querySelectorAll<HTMLElement>('[data-version]').forEach((el) => (el.textContent = `v${latest.version}`));
  if (latest.apk) {
    const mb = Math.round(latest.apk.size / 1e6);
    if (mb > 0)
      document.querySelectorAll<HTMLElement>('[data-size]').forEach((el) =>
        (el.textContent = el.textContent?.trim().startsWith('·') ? `· ${mb} MB` : `${mb} MB`));
    document.querySelectorAll<HTMLAnchorElement>('[data-apk-link]').forEach((a) => (a.href = latest.apk!.url));
  }
  if (!i18n || !sec) return;

  const sub = sec.querySelector('[data-upd-sub]');
  // a count from the feed's last ten entries would be wrong, so none is shown
  if (sub && data.first && !data.partial) {
    const since = new Date(data.first).toLocaleDateString(i18n.locale, { month: 'long', year: 'numeric' });
    sub.textContent = i18n.sub.replace('§n§', String(data.total)).replace('§since§', since);
  }
  const track = sec.querySelector<HTMLOListElement>('[data-upd-track]');
  if (!track) return;
  const fmt = (d: string) => new Date(d).toLocaleDateString(i18n.locale, { day: 'numeric', month: 'short', year: 'numeric' });
  const all = track.lastElementChild!;
  const cards = data.releases.slice(0, 10).map((r, i) => {
    const li = document.createElement('li');
    li.className = `rel surface-m${i === 0 ? ' rel-new' : ''}`;
    const a = document.createElement('a');
    a.href = r.url;
    a.rel = 'noopener';
    const v = Object.assign(document.createElement('span'), { className: 'rel-v dots', textContent: r.version });
    const time = Object.assign(document.createElement('time'), { dateTime: r.date, textContent: fmt(r.date) });
    const title = Object.assign(document.createElement('span'), { className: 'rel-t', textContent: r.title, lang: 'de' });
    a.append(v, time, title);
    if (r.points > 0) {
      a.append(Object.assign(document.createElement('span'), {
        className: 'rel-p',
        textContent: r.points === 1 ? i18n.one : i18n.many.replace('§n§', String(r.points)),
      }));
    }
    li.append(a);
    return li;
  });
  track.replaceChildren(...cards, all);
  // the strip is wider or narrower now
  ScrollTrigger.refresh();
}
