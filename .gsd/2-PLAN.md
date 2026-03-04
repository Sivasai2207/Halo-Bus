# 2-PLAN: Deep Rebranding

<task type="auto">
  <name>Scrub "Halo Bus" and "Halo Bus Track" from Frontend</name>
  <files>frontend/owner-portal/src/**/*, frontend/college-portal/src/**/*, frontend/**/*.html</files>
  <action>
    - Replace "Halo Bus Track" with "Halo Bus Track" (case sensitive).
    - Replace "Halo Bus" with "Halo Bus" (case sensitive).
    - Replace "halobus" with "halobus" (case sensitive).
  </action>
  <verify>Run `grep -ri "Halo Bus" frontend`</verify>
  <done>Frontend UI is completely rebranded to Halo Bus.</done>
</task>

<task type="auto">
  <name>Scrub "TransitHub" and "Bannu" remainders</name>
  <files>Entire project</files>
  <action>
    - Run a final case-insensitive pass for "TransitHub" and "Bannu" across the whole repo.
  </action>
  <verify>Run `grep -riE "transithub|bannu" .`</verify>
  <done>No traces of previous internal names remain.</done>
</task>

<task type="auto">
  <name>Update Page Titles and Metadata</name>
  <files>frontend/**/index.html, frontend/**/package.json</files>
  <action>
    - Ensure all `<title>` tags and `package.json` descriptions reflect "Halo Bus".
  </action>
  <verify>Check index.html files.</verify>
  <done>Metadata is correctly rebranded.</done>
</task>

<task type="auto">
  <name>Verify with Localhost</name>
  <files>N/A</files>
  <action>
    - Start `frontend/owner-portal` again.
    - Check the login page to confirm "Halo Bus" is gone and "Halo Bus" is present.
  </action>
  <verify>Browser screenshot of the login page.</verify>
  <done>Visual verification of branding.</done>
</task>
