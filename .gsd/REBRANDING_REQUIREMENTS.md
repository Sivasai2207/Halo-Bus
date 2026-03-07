# Requirements: Rebranding & Stabilization

## Scope
1. **Global Rebrand**:
   - Replace "Halo Bus" with "Halo Bus" in all source code files.
   - Update `title` tags in HTML/React.
   - Update placeholders, footer credits, and labels in the UI.
   - Ensure case sensitivity is handled (Halo Bus -> Halo Bus, Halo Bus -> halo bus).
2. **Firebase Rules Sync**:
   - Perform a bit-for-bit sync of `firestore.rules` from Bannu Bus to HaloBus (already verified discrepancies in `attendance` and `user_notifications`).
3. **Firebase API Key Fix**:
   - Resolve the `auth/invalid-api-key` error shown on the College Portal login/find-organization screen.
   - Inspect `.env` and `firebaseConfig.js` (or similar) files.

## Out of Scope
- Logo image generation (unless requested).
- Database migration (rebranding only affects UI/client-side strings).

