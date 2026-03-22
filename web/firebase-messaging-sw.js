// Firebase Messaging service worker for Flutter web.
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCR-I1laHjoLoOMJecCuW4Ex_s8HPICSxQ',
  appId: '1:68200966561:web:d86346473fb9dffd33c3e0',
  messagingSenderId: '68200966561',
  projectId: 'flap-app-5c0c2',
  authDomain: 'flap-app-5c0c2.firebaseapp.com',
  storageBucket: 'flap-app-5c0c2.firebasestorage.app',
  measurementId: 'G-9NH9HR5NXR',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const title = notification.title || 'FLAP';
  const options = {
    body: notification.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(title, options);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
      return null;
    })
  );
});

