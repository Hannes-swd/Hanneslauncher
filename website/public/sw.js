// Shows pushed messages and opens the page they point to.
self.addEventListener('push', (e) => {
  const m = e.data ? e.data.json() : {};
  e.waitUntil(
    self.registration.showNotification(m.title || 'hanneslauncher', {
      body: m.body || '',
      icon: '/favicon.png',
      data: { url: m.url || '/' },
    }),
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(clients.openWindow(e.notification.data.url));
});
