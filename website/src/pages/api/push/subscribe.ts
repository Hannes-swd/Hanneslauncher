import type { APIRoute } from 'astro';
import { addSub, removeSub, storeReady } from '../../../push/store';

// Visitors opt in from the browser; nothing is stored before they do.
export const prerender = false;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });

export const POST: APIRoute = async ({ request }) => {
  if (!storeReady()) return json({ error: 'not configured' }, 503);
  const s = await request.json().catch(() => null);
  if (!s?.endpoint?.startsWith('https://') || !s.keys?.p256dh || !s.keys?.auth) {
    return json({ error: 'bad subscription' }, 400);
  }
  await addSub({ endpoint: s.endpoint, keys: { p256dh: s.keys.p256dh, auth: s.keys.auth } });
  return json({ ok: true });
};

export const DELETE: APIRoute = async ({ request }) => {
  if (!storeReady()) return json({ error: 'not configured' }, 503);
  const s = await request.json().catch(() => null);
  if (typeof s?.endpoint !== 'string') return json({ error: 'bad request' }, 400);
  await removeSub(s.endpoint);
  return json({ ok: true });
};
