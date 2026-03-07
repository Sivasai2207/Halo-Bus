# Phase 8 Plan: Student App Bug Fixes

## Tasks

<task type="auto">
  <name>Fix Firestore Notifications Rules</name>
  <files>firestore.rules</files>
  <action>
    Update `user_notifications` rule to allow `list` and `read` for authenticated students.
  </action>
</task>

<task type="auto">
  <name>Add Absentee Notifications to History</name>
  <files>frontend/college-portal/server/controllers/notificationController.js</files>
  <action>
    Update `sendTripEndedNotification` to write `user_notifications` documents for absent students.
  </action>
</task>

<task type="auto">
  <name>Fix Home UI Gray Layer</name>
  <files>mobile/lib/features/shell/student_shell.dart, mobile/lib/features/student/screens/student_home.dart</files>
  <action>
    Simplify nested Scaffolds. Replace `AppScaffold` in `StudentShell` with a root `Scaffold`.
  </action>
</task>

<task type="auto">
  <name>Harden Notifications UI</name>
  <files>mobile/lib/features/student/screens/notification_screen.dart</files>
  <action>
    Add explicit Delete buttons and apply Soft Green theme colors.
  </action>
</task>

<task type="auto">
  <name>Deploy Rules & Git Push</name>
  <files>firestore.rules</files>
  <action>
    Check for unpushed changes and push to git. (Firebase deploy manual or via script).
  </action>
</task>

<task type="auto">
  <name>Build APK v8</name>
  <files>mobile/build/app/outputs/flutter-apk/app-release.apk</files>
  <action>
    Generate a new release APK for the student app.
  </action>
</task>
