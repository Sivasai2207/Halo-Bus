# PLAN: Phase 1 - Research & Diagnostics

<task type="auto">
  <name>Audit Firestore Data Alignment</name>
  <files>Firestore (audit via script)</files>
  <action>
    Run a diagnostic script to:
    1. Find all students for college 'olentangy-schools'.
    2. List their 'assignedBusId' and 'studentId' fields.
    3. Find all buses for college 'olentangy-schools' and list their IDs.
    4. Verify if student 'assignedBusId' actually exists in the 'buses' collection.
  </action>
  <verify>Check script output for 'MISMATCH' or 'NOT FOUND' warnings.</verify>
  <done>Verified that students are linked to valid, existing bus IDs within the same college.</done>
</task>

<task type="auto">
  <name>Trace Driver Student API Endpoint</name>
  <files>frontend/college-portal/server/routes/driver.routes.js, frontend/college-portal/server/controllers/driverController.js</files>
  <action>
    1. Examine the router definition to confirm the exact path for fetching students.
    2. Check the controller 'getBusStudents' to see exactly how 'busId' is used in the query.
    3. Look for any middleware that might be returning 404 before the controller is reached.
  </action>
  <verify>Successful identification of the 404 source (Route mismatch vs. Controller logic vs. Middleware).</verify>
  <done>Path and logic for fetching students is confirmed and aligns with mobile app requests.</done>
</task>

<task type="auto">
  <name>Simulate Student Login Backend Logic</name>
  <files>frontend/college-portal/server/controllers/authController.js</files>
  <action>
    Run a script to simulate 'studentLogin' for 'prasad@gmail.com' and 'karthik@gmail.com' using the same logic as the controller.
    1. Query Firestore for the student.
    2. Check 'isFirstLogin' and 'registerNumber' comparison.
    3. Check 'passwordHash' comparison if not first login.
  </action>
  <verify>Output results of simulated login (Success/Failure reason).</verify>
  <done>Root cause of student login failure is identified (e.g., hash mismatch, missing field, or case sensitivity).</done>
</task>
