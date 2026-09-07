const APP_URL = '/';

self.addEventListener('push', (event) => {
  let payload = {};

  try {
    payload = event.data ? event.data.json() : {};
  } catch (_) {
    payload = { body: event.data ? event.data.text() : '' };
  }

  const data = payload.data || payload;
  const category = data.category;
  const allowedCategories = [
    'daily_prep',
    'streak',
    'daily_goal',
    'achievement',
  ];

  if (!allowedCategories.includes(category)) return;

  const title = payload.title || 'Neo 150 Prep';
  const body = payload.body || 'Your next prep session is waiting.';
  const destination = data.destination || APP_URL;

  event.waitUntil(
    self.registration.showNotification(title, {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: {
        category,
        destination,
        entity_id: data.entity_id || null,
        event_identifier: data.event_identifier || null,
      },
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const destination = event.notification.data?.destination || APP_URL;
  const targetUrl = new URL(destination, self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }

      return clients.openWindow(targetUrl);
    }),
  );
});
