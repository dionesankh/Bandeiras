# Implementation Plan - Restore API 36 and Consolidate APK Signing

Restore the project to Target SDK 36 (Android 16) and confirm the signing integrity to resolve installation issues on other devices.

## User Review Required

> [!IMPORTANT]
> **Root Cause Investigation**: The "Invalid Package" error is being investigated. Hypotheses include:
> - Absence of V1 (JAR) signature.
> - Certificate conflict with a previous installation.
> - APK corruption during transfer.
> - Post-signing file modifications.
>
> **Action**: I will restore API 36 and the latest library versions while keeping explicit V1/V2 signing enabled to ensure maximum compatibility.

## Proposed Changes

### [Component] Build Configuration

#### [MODIFY] [variables.gradle](file:///D:/Bandeiras/android/variables.gradle)
- Restore `compileSdkVersion` and `targetSdkVersion` to **36**.
- Restore `androidx.activity:activity` to **1.11.0**.
- Restore `androidx.core:core` to **1.17.0**.
- Restore `androidx.webkit:webkit` to **1.14.0**.
- Maintain `minSdkVersion` at **24**.

#### [MODIFY] [app/build.gradle](file:///D:/Bandeiras/android/app/build.gradle)
- Ensure the `signingConfigs` block for the debug build has `v1SigningEnabled true` and `v2SigningEnabled true` explicitly set.
- This will use the default Android debug key unless otherwise specified, maintaining consistency.

## Verification Plan

### Automated Tests
- Run `node scripts/build-android.js` (from project root) to refresh web assets.
- Run `./gradlew :app:assembleDebug` to generate the new APK.
- Run `apksigner verify --verbose --print-certs` on the resulting APK.
- Attempt installation via ADB: `adb install -r app-debug.apk` and capture any `INSTALL_FAILED_*` error codes.

### Reporting
The following information will be provided in the final report:
- V1, V2, and V3 verification status.
- Certificate details and SHA-256 fingerprint.
- `applicationId`.
- Effective `minSdkVersion` and `targetSdkVersion`.
- Final APK path and exact file size.
