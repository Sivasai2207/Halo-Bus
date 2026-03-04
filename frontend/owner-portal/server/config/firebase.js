const admin = require('firebase-admin');
const dotenv = require('dotenv');

dotenv.config();

// Initialize Firebase Admin with Service Account from Individual Environment Variables
// This approach is more reliable for deployment platforms like Vercel
// where JSON strings with newlines can be problematic.

/**
 * Bulletproof private key parser.
 * Handles ALL formats:
 *   - Vercel: stores the key with real newlines (no escaping needed)
 *   - .env files: stores the key with literal \n that need replacing
 */
function parsePrivateKey(raw) {
    if (!raw) return null;
    let key = raw.trim();
    if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
        key = key.slice(1, -1);
    }
    key = key.replace(/\\n/g, '\n');
    const beginTag = '-----BEGIN PRIVATE KEY-----';
    const endTag = '-----END PRIVATE KEY-----';
    const startIdx = key.indexOf(beginTag);
    const endIdx = key.indexOf(endTag);
    if (startIdx === -1 || endIdx === -1) return null;
    return key.substring(startIdx, endIdx + endTag.length).trim() + '\n';
}

try {
    let serviceAccount = null;
    const path = require('path');
    const fs = require('fs');

    // 1. Try local JSON file first
    const serviceAccountPath = path.join(__dirname, '..', '..', 'service-account.json');
    if (fs.existsSync(serviceAccountPath)) {
        try {
            serviceAccount = require(serviceAccountPath);
            console.log('[Firebase] Using local service-account.json');
        } catch (e) {
            console.error('[Firebase] Failed to load local service-account.json:', e.message);
        }
    }

    // 2. Fallback to individual environment variables
    if (!serviceAccount) {
        const projectId = process.env.FIREBASE_PROJECT_ID;
        const privateKeyRaw = process.env.FIREBASE_PRIVATE_KEY;
        const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;

        if (projectId && privateKeyRaw && clientEmail) {
            const privateKey = parsePrivateKey(privateKeyRaw);
            serviceAccount = { projectId, privateKey, clientEmail };
            console.log('[Firebase] Using environment variable credentials');
        }
    }

    if (!serviceAccount) {
        console.warn('Missing Firebase environment variables and local service-account.json not found.');
    }

    if (serviceAccount && !admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
        console.log(`Firebase Admin Initialized - Project: ${serviceAccount.project_id || serviceAccount.projectId}`);
    }
} catch (error) {
    console.error("Firebase Initialization Error:", error.message);
    process.exit(1);
}

const db = admin.firestore();
const auth = admin.auth();

module.exports = { admin, db, auth };
