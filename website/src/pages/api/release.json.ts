import type { APIRoute } from 'astro';
import { fetchReleases } from '../../data/releases';

// Runs on Vercel, not in the browser: the page asks this instead of GitHub,
// so visitors never talk to a third party just by opening the site. The CDN
// keeps an answer for 15 minutes and serves the old one for a day while a
// fresh one is fetched.
export const prerender = false;

export const GET: APIRoute = async () => {
  try {
    const data = await fetchReleases();
    return new Response(JSON.stringify({ ...data, releases: data.releases.slice(0, 12) }), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, s-maxage=900, stale-while-revalidate=86400',
      },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: (e as Error).message }), {
      status: 502,
      headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
    });
  }
};
