export default function handler(req, res) {
    res.status(200).json({
        message: "Diagnostics",
        node_version: process.version,
        env: {
            FIREBASE_PROJECT_ID: !!process.env.FIREBASE_PROJECT_ID,
            FIREBASE_CLIENT_EMAIL: !!process.env.FIREBASE_CLIENT_EMAIL,
            FIREBASE_PRIVATE_KEY: !!process.env.FIREBASE_PRIVATE_KEY,
            FIREBASE_PRIVATE_KEY_LENGTH: process.env.FIREBASE_PRIVATE_KEY ? process.env.FIREBASE_PRIVATE_KEY.length : 0,
            NODE_ENV: process.env.NODE_ENV,
            VITE_API_URL: !!process.env.VITE_API_URL
        },
        cwd: process.cwd(),
        files: require('fs').readdirSync(process.cwd())
    });
}
