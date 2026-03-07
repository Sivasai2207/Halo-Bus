# Phase 8 Context: Student App Bug Fixes

## 1. Firebase Permission Error
- **Symptom**: `[cloud_firestore/permission-denied]` when accessing the Notifications screen.
- **Root Cause**: The rule for `user_notifications` matches document-level but may fail collection-level listing if not perfectly aligned.
- **Decision**: Update `firestore.rules` to allow `read` more robustly and explicitly add `list` if needed.

## 2. Gray Layer UI Bug
- **Symptom**: A semi-transparent gray layer on the home screen.
- **Root Cause**: Nested `AppScaffold` in `StudentShell` and `StudentHomeScreen`. Double scaffolds in Flutter cause stacking of overlays/elevation.
- **Decision**: Simplify `StudentShell` to a standard `Scaffold`.

## 3. Missing Notification History
- **Symptom**: Absentees from trips don't see history in the bell icon.
- **Root Cause**: `notificationController.js` sends FCM but doesn't write to `user_notifications`.
- **Decision**: Update backend to write to `user_notifications`.
