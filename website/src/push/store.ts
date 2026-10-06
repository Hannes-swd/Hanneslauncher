// Where push subscriptions live. Vercel functions have no disk, so this talks
// to an Upstash Redis (Vercel Marketplace) over its REST API. Until the two
// env vars exist, nothing is stored and subscribing answers 503.
export type Sub = { endpoint: string; keys: { p256dh: string; auth: string } };

const KEY = 'push:subs'; // one hash: endpoint -> JSON of the subscription

const cfg = () => {
  const url = import.meta.env.UPSTASH_REDIS_REST_URL;
  const token = import.meta.env.UPSTASH_REDIS_REST_TOKEN;
  return url && token ? { url, token } : null;
};

export const storeReady = () => cfg() !== null;

async function cmd(...args: string[]): Promise<unknown> {
  const c = cfg();
  if (!c) throw new Error('push storage not configured');
  const res = await fetch(c.url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${c.token}` },
    body: JSON.stringify(args),
  });
  if (!res.ok) throw new Error(`storage ${res.status}`);
  return ((await res.json()) as { result: unknown }).result;
}

export const addSub = (s: Sub) => cmd('HSET', KEY, s.endpoint, JSON.stringify(s));
export const removeSub = (endpoint: string) => cmd('HDEL', KEY, endpoint);

export async function listSubs(): Promise<Sub[]> {
  const flat = (await cmd('HVALS', KEY)) as string[];
  return flat.map((v) => JSON.parse(v) as Sub);
}
