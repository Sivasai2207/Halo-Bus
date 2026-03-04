# PROJECT: Halo Bus Tracking

## Vision
A comprehensive multi-tenant bus tracking and attendance system for educational institutions.

## Tech Stack
- **Frontend (Mobile):** Flutter with Riverpod for state management.
- **Backend:** Node.js, Express, Vercel (Serverless).
- **Database:** Firebase Cloud Firestore.
- **Auth:** Firebase Authentication with Custom Tokens for unified role-based login.

## Non-Negotiable Constraints
- **Multi-tenancy:** All data must be isolated by `collegeId`.
- **Security:** Strict Firestore rules and backend verification.
- **Reliability:** Background tracking for drivers and instant notifications for parents/students.
- **Offline Capable:** Local caching of attendance for weak network scenarios.
