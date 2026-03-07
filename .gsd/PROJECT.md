# Project: Feature Migration from Bannu Bus Application

## Vision
Migrate a massive set of features and UI improvements introduced in the "Bannu Bus Application" test environment to the "HaloBus Live Tracking" production environment. This synchronization will bring the latest innovations to HaloBus, specifically regarding college portal theming, security (OTP), mobile notifications, and new administrative drop-off flows.

## Tech Stack
- **Frontend**: React / Next.js (College Portal)
- **Mobile**: Flutter / Dart (Student and Driver Apps)
- **Backend**: Node.js / Express
- **Database / Backend Services**: MongoDB, Firebase (Authentication, FCM, Rules)

## Non-negotiable Constraints
- The migration must not break or inadvertently overwrite existing, stable production functionality in HaloBus not explicitly targeted.
- Project-specific configurations, environment variables, and unique IDs for HaloBus must remain strictly intact (do not blindly overwrite `.env` or configurations with Bannu Bus values).
