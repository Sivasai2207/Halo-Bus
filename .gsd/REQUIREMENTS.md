# REQUIREMENTS: Trip Logic & Notification Fixes

## In-Scope
- **Notification Fixes:** Ensure 'Arriving', 'Arrived', and 'Skipped' notifications are sent to students.
- **Skip Logic:** Fix 'Skip' button to correctly update Firestore and notify students.
- **End-Trip Alerts:** Implement 'Not Boarded' (Absent) notifications at the end of the trip for all students not marked as attended.
- **Proximity Automation:** Auto-mark stops as 'Completed' when the bus leaves the stop radius or crosses the point.
- **Visual Feedback:** Correctly show ticks/status in the Student app's trip progress.

## Out-of-Scope
- UI refactoring.
- New reporting features.
