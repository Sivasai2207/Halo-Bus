# Phase 1 & 2: Context Gathering

## Findings
- **Backend Directory**: `HaloBus Live Tracking` does not have a root `backend/` folder like Bannu Bus; instead, its server logic is primarily located in `frontend/college-portal/server/`.
- **Frontend Directory**: Both have `frontend/college-portal` and `frontend/owner-portal`.
- **Mobile Directory**: Both use Flutter for the mobile app (`mobile/`).
- **Firebase Rules**: Both have a `firestore.rules` file at the root.

## Strategy for Migration
1. **Phase 2 (UI)**: Copy the React components, CSS files, and Next/React structural files from `Bannu Bus Application/frontend/college-portal/src` to `HaloBus Live Tracking/frontend/college-portal/src` without overwriting the backend controllers in the same workspace unless directly related to OTP.
2. **Phase 3 (Firebase & OTP)**: Extract `otp` and `dropoff` rules from Bannu Bus `firestore.rules` and prepend/merge them into HaloBus `firestore.rules`.
3. **Phase 4 & 5 (Mobile & Drops)**: Direct merge of `.dart` files for OTP screens, bell notifications, and attendance handling.

Next step: Formulate exact Phase 1 and Phase 2 XML Tasks.
