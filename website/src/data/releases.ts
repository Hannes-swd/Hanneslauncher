// Releases come from GitHub, but never straight to the visitor's browser:
// the build bakes them into the page, and /api/release.json refreshes them
// server-side with a cache. That way a visit sends nobody's IP to GitHub.

// the repository's canonical name (the old 'Hanneslouncher' only redirects)
export const REPO = 'Hannes-swd/Hanneslauncher';
export const REPO_URL = `https://github.com/${REPO}`;
export const RELEASES_URL = `${REPO_URL}/releases`;

export type Release = {
  version: string;
  date: string;
  url: string;
  /** First line of the notes, markdown stripped. Written in German. */
  title: string;
  /** How many bullet points the notes list. */
  points: number;
  apk?: { url: string; size: number };
};

export type ReleaseData = {
  releases: Release[];
  total: number;
  first: string | null;
  fetchedAt: string;
  /** True when only the feed's newest entries were reachable, so total and
   *  first are unknown and must not be shown. */
  partial?: boolean;
};

const clean = (line: string) =>
  line
    .replace(/\*\*|__|`/g, '')
    .replace(/^#+\s*/, '')
    .replace(/^[-*]\s+/, '')
    .trim();

function titleOf(body: string): string {
  const line = (body || '').split(/\r?\n/).map(clean).find((l) => l.length > 0) ?? '';
  // One sentence is enough for a card; long single-line notes get cut at
  // the first sentence end or a semicolon.
  const cut = line.search(/[.;:](\s|$)/);
  const short = cut > 24 ? line.slice(0, cut) : line;
  return short.length > 120 ? short.slice(0, 117).trimEnd() + '…' : short;
}

export async function fetchReleases(): Promise<ReleaseData> {
  try {
    return await fromApi();
  } catch (e) {
    // GitHub's API allows 60 calls an hour per address without a token, and
    // build and function servers share addresses - the public feed is the
    // way round that.
    return await fromFeed();
  }
}

const decode = (s: string) =>
  s.replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'").replace(/&amp;/g, '&');

export async function fromFeed(): Promise<ReleaseData> {
  const res = await fetch(`${RELEASES_URL}.atom`, { headers: { 'User-Agent': 'hanneslauncher-website' } });
  if (!res.ok) throw new Error(`GitHub feed answered ${res.status}`);
  const xml = await res.text();
  const entries = [...xml.matchAll(/<entry>([\s\S]*?)<\/entry>/g)].map((m) => m[1]);
  const releases: Release[] = entries.map((e) => {
    const tag = (/<title>([^<]+)<\/title>/.exec(e)?.[1] ?? '').trim();
    const version = tag.replace(/^v/, '');
    const html = decode(/<content[^>]*>([\s\S]*?)<\/content>/.exec(e)?.[1] ?? '');
    const text = html
      .replace(/<li>/g, '\n- ')
      .replace(/<\/(p|li|h\d)>/g, '\n')
      .replace(/<[^>]+>/g, '');
    return {
      version,
      date: /<updated>([^<]+)<\/updated>/.exec(e)?.[1] ?? '',
      url: /<link[^>]*href="([^"]+)"/.exec(e)?.[1] ?? `${RELEASES_URL}/tag/${tag}`,
      title: titleOf(decode(text)),
      points: (html.match(/<li>/g) ?? []).length,
      // tool/release.ps1 always names the file like this
      apk: { url: `${RELEASES_URL}/download/${tag}/hanneslauncher-${version}.apk`, size: 0 },
    };
  });
  if (releases[0]?.apk) {
    try {
      const head = await fetch(releases[0].apk.url, { method: 'HEAD', redirect: 'follow' });
      releases[0].apk.size = Number(head.headers.get('content-length')) || 0;
    } catch { /* size stays unknown */ }
  }
  return { releases, total: releases.length, first: null, fetchedAt: new Date().toISOString(), partial: true };
}

async function fromApi(): Promise<ReleaseData> {
  const headers: Record<string, string> = {
    Accept: 'application/vnd.github+json',
    'User-Agent': 'hanneslauncher-website',
  };
  const token = typeof process !== 'undefined' ? process.env.GITHUB_TOKEN : undefined;
  if (token) headers.Authorization = `Bearer ${token}`;

  const res = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100`, { headers });
  if (!res.ok) throw new Error(`GitHub answered ${res.status}`);
  const raw = (await res.json()) as any[];
  const published = raw.filter((r) => !r.draft && !r.prerelease);

  const releases: Release[] = published.map((r) => {
    const apk = (r.assets ?? []).find((a: any) => String(a.name).endsWith('.apk'));
    return {
      version: String(r.tag_name).replace(/^v/, ''),
      date: r.published_at,
      url: r.html_url,
      title: titleOf(r.body),
      points: String(r.body || '').split(/\r?\n/).filter((l) => /^\s*[-*]\s+/.test(l)).length,
      apk: apk ? { url: apk.browser_download_url, size: apk.size } : undefined,
    };
  });

  return {
    releases,
    total: releases.length,
    first: releases.length ? releases[releases.length - 1].date : null,
    fetchedAt: new Date().toISOString(),
  };
}

/** Build-time copy, fetched once for all pages; an empty set if GitHub is
 *  unreachable while building. */
let atBuild: Promise<ReleaseData> | null = null;
export function releasesAtBuild(): Promise<ReleaseData> {
  atBuild ??= fetchReleases().catch((e) => {
    console.warn('[releases] build without GitHub data:', (e as Error).message);
    return { releases: [], total: 0, first: null, fetchedAt: new Date().toISOString() };
  });
  return atBuild;
}
