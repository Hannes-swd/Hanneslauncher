// Sending lives here and is deliberately NOT reachable from any route yet.
// The later admin panel (behind its own login) is the only thing that should
// call broadcast().
import webpush from 'web-push';
import { listSubs, removeSub } from './store';

export type Message = { title: string; body: string; url?: string };

export async function broadcast(msg: Message) {
  const pub = import.meta.env.VAPID_PUBLIC_KEY;
  const priv = import.meta.env.VAPID_PRIVATE_KEY;
  if (!pub || !priv) throw new Error('VAPID keys missing');
  webpush.setVapidDetails(import.meta.env.VAPID_SUBJECT ?? 'mailto:stellarfrog0@gmail.com', pub, priv);

  const payload = JSON.stringify(msg);
  let sent = 0;
  let gone = 0;
  for (const sub of await listSubs()) {
    try {
      await webpush.sendNotification(sub, payload);
      sent++;
    } catch (e) {
      // 404/410: the visitor revoked permission or cleared the browser
      const code = (e as { statusCode?: number }).statusCode;
      if (code === 404 || code === 410) {
        await removeSub(sub.endpoint);
        gone++;
      }
    }
  }
  return { sent, gone };
}
