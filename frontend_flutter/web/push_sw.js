// Push notification service worker for Family Planner PWA
// Registered at scope /push/ so it doesn't conflict with Flutter's service worker

self.addEventListener('push', (event) => {
  const data = event.data ? event.data.json() : {};
  const title = data.title || 'Family Planner';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: data.url || '/' },
    vibrate: [200, 100, 200],
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const targetUrl = (event.notification.data && event.notification.data.url) || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      if (windowClients.length > 0) {
        // Navigate the first existing window to the target URL, then focus it
        const client = windowClients[0];
        return client.navigate(targetUrl).then((c) => (c || client).focus());
      }
      // No window open — open a new one
      return clients.openWindow(targetUrl);
    })
  );
});
