import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getAuth } from 'firebase/auth';
import { getMessaging } from 'firebase/messaging';

// Web app's Firebase configuration for halo-bus
const firebaseConfig = {
    apiKey: "AIzaSyD3qT21T11QPD5O_49pBNnQ0WFE3u0AJzQ",
    authDomain: "halo-bus.firebaseapp.com",
    projectId: "halo-bus",
    storageBucket: "halo-bus.firebasestorage.app",
    messagingSenderId: "86666729917",
    appId: "1:86666729917:web:de70b266a051f0c2921ad4",
    measurementId: "G-EVFDPZ4E4D"
};

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);

export const auth = getAuth(app);
export const messaging = getMessaging(app);
export default app;
