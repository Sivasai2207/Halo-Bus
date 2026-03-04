
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging-compat.js');

const firebaseConfig = {
    apiKey: "AIzaSyD3qT21T11QPD5O_49pBNnQ0WFE3u0AJzQ",
    authDomain: "halo-bus.firebaseapp.com",
    projectId: "halo-bus",
    storageBucket: "halo-bus.firebasestorage.app",
    messagingSenderId: "86666729917",
    appId: "1:86666729917:web:de70b266a051f0c2921ad4"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification.title;
    const notificationOptions = {
        body: payload.notification.body,
        icon: '/logo192.png' // Modify if you have a specific logo path
    };

    self.registration.showNotification(notificationTitle, notificationOptions);
});
