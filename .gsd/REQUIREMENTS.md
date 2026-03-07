# Requirements: Migration Arc

## Scope
1. **College Portal UI Theme Migration**: Transfer theme, colors, cards, and overall UI components across all screens from `Bannu Bus Application` to `HaloBus Live Tracking`.
2. **Firebase Rules**: Copy the complete architecture and Firebase rules related to OTP generation and validation.
3. **Mobile App OTP & Notifications**: Transfer the complete OTP implementation and notification system into the mobile apps (Driver and Student).
4. **Student App Bell Icon**: Migrate the bell icon functionality from the student app.
5. **Admin Portal Dropoff Logic & Attendance**: Transfer the complete logic for the new dropoff status, OTP verification/validation (including error handling: "Wrong OTP entered. Please retry."), OTP notifications, and attendance logic from the web admin portal, driver app, and student app.

## Out of Scope
- Modifying features that exist solely in HaloBus and were not part of the Bannu Bus functionality suite.
- Overwriting environment-specific variables, keys, or distinct deployment details belonging explicitly to the HaloBus production tier.
