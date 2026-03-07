# Roadmap: Migration Arc

## Phase 1: Context & Validation
- Analyze the exact file differences between the `Bannu Bus Application` directory and the `HaloBus Live Tracking` project.
- Identify discrepancies in dependencies, database schemas, or state-management approaches to ensure a smooth transition.

## Phase 2: College Portal UI Migration
- Migrate the UI theme (colors, tailwind/CSS configs).
- Transfer UI components (Cards, Modals, Navbars, Layouts).
- Verify the College Portal UI loads correctly in the `HaloBus` environment.

## Phase 3: Firebase Rules & OTP Architecture
- Migrate the `firebase.rules` and architecture related to OTPs.
- Transfer OTP generation, validation logic, and routing (server-side controllers and mobile services).

## Phase 4: Mobile App Migrations (OTP, Notifications, Bell Icon)
- Transfer the bell icon component and related UI states in the Student App.
- Integrate the OTP screens, states, and logic into both the Driver and Student Apps.
- Update `notification_service.dart` and the push notification handlers.

## Phase 5: Admin Dropoff Logic & Centralized Attendance
- Migrate the admin portal drop-off controller logic, handling the new "dropoff" statuses.
- Implement OTP validation error handling flows across the frontends.
- Integrate the completed attendance and notification logic centrally across the web, driver, and student applications.
