# ROADMAP: Error Resolution Phase

## Phase 1: Research & Diagnostics (Current)
- [ ] Verify backend deployment status and logs.
- [ ] Audit `collegeId` and `busId` consistency in Firestore.
- [ ] Trace `busStudentsProvider` and API endpoint request/response.
- [ ] Test student login with specific accounts (**prasad@gmail.com**, **karthik@gmail.com**).

## Phase 2: Implementation & Fixes
- [ ] Correct API endpoint mismatch or data lookup logic in `driverController.js`.
- [ ] Harden student login comparison (register number vs password).
- [ ] Synchronize `collegeId` across all relevant documents (Colleges, Users, Students, Buses).

## Phase 3: Verification & Handover
- [ ] Re-test with new Release APK.
- [ ] Verify logs show successful student fetch and login.
- [ ] Update documentation and walkthrough.
