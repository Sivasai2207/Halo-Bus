# ROADMAP: Global Trip Fix & Attendance Sync

## Phase 1: Research & Trace (10 mins)
- [ ] Trace 'Skip' action from Mobile App to Backend.
- [ ] Verify FCM token fetching and targeting in `notificationController.js`.
- [ ] Audit `driver_trip_screen.dart` for direct proximity triggers.

## Phase 2: Implementation (15 mins)
- [ ] Fix `sendStopEventNotification` to include targeting for 'Skipped' events.
- [ ] Implement absent notification loop in `endTrip` controller.
- [ ] Add 'Completed' auto-trigger in background tracking service.

## Phase 3: Verification (5 mins)
- [ ] Verify logs show FCM success.
- [ ] Test 'Skip' on a live trip (using simulation or manual update).
- [ ] Build final Release APK for meeting.
