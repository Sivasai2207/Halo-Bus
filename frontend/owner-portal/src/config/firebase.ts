// Import the functions you need from the SDKs you need
import { initializeApp } from "firebase/app";
import { getAnalytics } from "firebase/analytics";
import { getFirestore } from "firebase/firestore";
import { getAuth, GoogleAuthProvider } from "firebase/auth";

// Your web app's Firebase configuration
const firebaseConfig = {
    apiKey: "AIzaSyD3qT21T11QPD5O_49pBNnQ0WFE3u0AJzQ",
    authDomain: "halo-bus.firebaseapp.com",
    projectId: "halo-bus",
    storageBucket: "halo-bus.firebasestorage.app",
    messagingSenderId: "86666729917",
    appId: "1:86666729917:web:de70b266a051f0c2921ad4",
    measurementId: "G-EVFDPZ4E4D"
};

// Initialize Firebase
const app = initializeApp(firebaseConfig);
const analytics = getAnalytics(app);
const db = getFirestore(app);
const auth = getAuth(app);
const googleProvider = new GoogleAuthProvider();

export { app, db, analytics, auth, googleProvider };
