# STATE: Phase 1 Complete - Root Cause Found

## Current Position
Entering Phase 2: Implementation & Fixes.

## Major Discovery
- **Root Cause:** Backend initialization logic in `firebase.js` is looking for `service-account.json` in the `server/` directory, but the file exists in the parent `college-portal/` directory.
- **Consequence:** Backend falls back to Vercel Env Vars, which are likely still pointing to the old `live-bus-tracking-2ec59` project. This project lacks the data for `olentangy-schools`, causing 404s for buses and "User Not Found" for student logons.

## Architectural Decisions
- Move service account files to their expected local paths.
- Enforce Environment Variables as the primary source of truth for production (Vercel).

## Blockers
- None. I have a clear path to fix.
