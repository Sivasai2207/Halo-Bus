# PLAN: Phase 2 - Implementation & Fixes

<task type="auto">
  <name>Relocate Service Account Files</name>
  <files>frontend/college-portal/server/service-account.json, frontend/owner-portal/server/service-account.json</files>
  <action>
    The backend 'firebase.js' expects the service account in its parent directory (server/).
    Current files are in 'frontend/college-portal/' and 'frontend/owner-portal/'.
    1. Copy 'frontend/college-portal/service-account.json' to 'frontend/college-portal/server/service-account.json'.
    2. Copy 'frontend/owner-portal/service-account.json' to 'frontend/owner-portal/server/service-account.json'.
  </action>
  <verify>Run 'ls' in both server directories to confirm files are present.</verify>
  <done>Service account files are in the locations expected by the backend initialization logic.</done>
</task>

<task type="auto">
  <name>Improve Backend Initialization Logging</name>
  <files>frontend/college-portal/server/config/firebase.js</files>
  <action>
    Add explicit logging to 'firebase.js' to show:
    1. Which file path it is checking for service account.
    2. The project ID of the credential actually used.
  </action>
  <verify>Check console logs (or Vercel logs) for the new initialization messages.</verify>
  <done>Backend clearly reports its connection status and project ID on startup.</done>
</task>

<task type="auto">
  <name>Generate Vercel Env Var Guide</name>
  <files>NONE (Instructions for User)</files>
  <action>
    Provide the user with the exact values for:
    - FIREBASE_PROJECT_ID
    - FIREBASE_CLIENT_EMAIL
    - FIREBASE_PRIVATE_KEY
    This ensures that even if the JSON file is missing in Vercel (e.g. if it's gitignored), the backend still works.
  </action>
  <verify>User confirms they have updated Vercel environment variables.</verify>
  <done>Production environment is correctly configured with Halo Bus credentials.</done>
</task>
