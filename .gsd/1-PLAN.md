# 1-PLAN: Identity & Package Renaming

<task type="auto">
  <name>Rename Flutter Project and App Name</name>
  <files>mobile/pubspec.yaml, mobile/android/app/src/main/AndroidManifest.xml, mobile/ios/Runner/Info.plist</files>
  <action>
    - Update `name` in `mobile/pubspec.yaml` to `halobus`.
    - Update `label` in `mobile/android/app/src/main/AndroidManifest.xml` to `Halo Bus`.
    - Update `CFBundleName` and `CFBundleDisplayName` in `mobile/ios/Runner/Info.plist` to `Halo Bus`.
  </action>
  <verify>Check files for updated strings.</verify>
  <done>Flutter project and app display names are updated.</done>
</task>

<task type="auto">
  <name>Rename Android Package and Namespace</name>
  <files>mobile/android/app/build.gradle, mobile/android/app/src/main/kotlin/com/bannu/mobile/mobile/MainActivity.kt</files>
  <action>
    - Update `namespace` and `applicationId` in `mobile/android/app/build.gradle` to `com.halobus.mobile`.
    - Move `MainActivity.kt` from `com.halobus.mobile.mobile` to `com.halobus.mobile` directory structure.
    - Update `package` declaration in `MainActivity.kt`.
  </action>
  <verify>Run `grep -r "com.halobus.mobile" mobile/android`</verify>
  <done>Android package is renamed to com.halobus.mobile.</done>
</task>

<task type="auto">
  <name>Rename iOS Bundle Identifier</name>
  <files>mobile/ios/Runner.xcodeproj/project.pbxproj</files>
  <action>
    - Search and replace `com.halobus.mobile.mobile` with `com.halobus.mobile` in `project.pbxproj`.
  </action>
  <verify>Check project.pbxproj for new bundle ID.</verify>
  <done>iOS bundle identifier is updated.</done>
</task>

<task type="auto">
  <name>Global Search and Replace - Brand Names</name>
  <files>Entire codebase</files>
  <action>
    - Replace "Halo Bus" with "Halo Bus" (case sensitive where appropriate).
    - Replace "Halo Bus" with "Halo Bus" or "halobus" (case sensitive).
    - Replace "Halo Bus" with "Halo Bus" (case sensitive).
  </action>
  <verify>Run `grep -riE "bannu|prasad|transithub" .`</verify>
  <done>No traces of old brand names remain in the codebase.</done>
</task>

<task type="auto">
  <name>Update Firebase Configuration Placeholders</name>
  <files>mobile/android/app/google-services.json, mobile/lib/firebase_options.dart</files>
  <action>
    - Update `package_name` in `google-services.json` to `com.halobus.mobile`.
    - Update `iosBundleId` in `firebase_options.dart` to `com.halobus.mobile`.
    - Note: User will need to provide actual new Firebase config files if they want it to connect to a new Firebase project.
  </action>
  <verify>Check files for updated package names.</verify>
  <done>Firebase config placeholders reflect the new package names.</done>
</task>
