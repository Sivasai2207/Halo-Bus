# 7-PLAN: Critical Notification & Tracking Fix [Urgant - 20min Deadline]

## Goal
Restore real-time "Arriving", "Arrived", and "Skipped" notifications and student-side state sync.

## Tasks

<task type="auto">
  <name>Harden /stop-event Route Validation</name>
  <files>frontend/college-portal/server/routes/driver.routes.js</files>
  <action>
    - Open `frontend/college-portal/server/routes/driver.routes.js`.
    - Modify the `router.post('/stop-event')` validation to include 'COMPLETED' in the allowed `type` list.
    - Add console logs for each validation field to debug incoming payloads.
  </action>
  <verify>Check logs during trip simulation.</verify>
  <done>The route accepts all 4 event types: ARRIVING, ARRIVED, SKIPPED, COMPLETED.</done>
</task>

<task type="auto">
  <name>Correct Notification Controller Query</name>
  <files>frontend/college-portal/server/controllers/notificationController.js</files>
  <action>
    - Open `frontend/college-portal/server/controllers/notificationController.js`.
    - In `sendStopEventNotification`, add a final fallback query that searches for students by `fcmToken` directly if no students are found by `assignedBusId`, for debugging purposes.
    - Add more granular logging for the student doc search results.
  </action>
  <verify>Verify 'Unified Query found X unique students' log in backend.</verify>
  <done>FCM tokens are correctly retrieved for all students assigned or favorited the bus.</done>
</task>

<task type="auto">
  <name>Verify Background Tracking Service Context</name>
  <files>mobile/lib/features/driver/services/background_tracking_service.dart</files>
  <action>
    - Ensure `collegeId` is correctly pulled from `SharedPreferences` in `_notifyServer` and `_handleArrivalEntry`, etc.
  </action>
  <verify>Manually trigger a notification and check backend logs for the correct `collegeId`.</verify>
  <done>The background service consistently sends the correct `collegeId`.</done>
</task>
