# PROJECT: Halo Bus Tracking - Trip Logic & Notifications

## Vision
A reliable, real-time tracking system that provides instant, accurate feedback to parents and students about bus proximity, stop status, and trip completion.

## Tech Stack
- **Mobile:** Flutter (Riverpod, Background Fetch, Dio).
- **Backend:** Express.js (Node.js), Firebase Admin SDK.
- **Real-time:** Cloud Firestore Snapshots, FCM (Push Notifications).

## Non-Negotiable Constraints
- **Latency:** Notifications must arrive within < 5 seconds of the event.
- **Reliability:** Background tracking must continue even when the app is minimized.
- **Consistency:** Stop status (Arrived, Skipped, Completed) must be synchronized across Driver, Student, and Parent apps.
