import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getMessaging } from 'firebase/messaging';

// Web app's Firebase configuration for live-bus-tracking-2ec59
const firebaseConfig = {
    apiKey: "AIzaSyBQ2YPWW3u0eQGngAb3iLaTZIo6io_MwCw",
    authDomain: "live-bus-tracking-2ec59.firebaseapp.com",
    projectId: "live-bus-tracking-2ec59",
    storageBucket: "live-bus-tracking-2ec59.firebasestorage.app",
    messagingSenderId: "34427841688",
    appId: "1:34427841688:web:fee9c73258614a1ff434ed",
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);

export const auth = getAuth(app);
export const messaging = getMessaging(app);
export default app;
