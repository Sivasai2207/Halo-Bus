# STATE: Critical Logic Sprint Initialized

## Current Position
Phase 1: Researching 404s and missing triggers.

## Architectural Decisions
- Use `sendStopEventNotification` as the unified entry point for all stop-related FCMs.
- Background service will own 'Arrived' and 'Arriving' triggers.

## Blockers
- Extremely tight deadline (30 mins).
- Need to verify if `targetStudentIds` are correctly passed from mobile for 'Skipped' events.
