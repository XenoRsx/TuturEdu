// web/firebase-messaging-sw.js
//
// Required for Web Push (see BLUEPRINT.md 5.12) - the firebase_messaging
// Flutter plugin auto-registers this file at the site root when
// FirebaseMessaging.instance.getToken() is first called. It's what lets a
// notification show up while the browser tab/app isn't focused (or is
// closed). Config values match lib/firebase_options.dart's `web` object.

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBIgRCHP5ytrizU4GjfkHD8IX6LTac36fA',
  appId: '1:885169577226:web:c024aca559e18188512ef3',
  messagingSenderId: '885169577226',
  projectId: 'tuturedu-app',
  authDomain: 'tuturedu-app.firebaseapp.com',
  storageBucket: 'tuturedu-app.firebasestorage.app',
});

firebase.messaging();
