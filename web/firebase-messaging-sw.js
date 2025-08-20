// Minimal FCM service worker for Flutter web
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'unused',
  appId: 'unused',
  messagingSenderId: 'unused',
  projectId: 'unused',
});

const messaging = firebase.messaging();

