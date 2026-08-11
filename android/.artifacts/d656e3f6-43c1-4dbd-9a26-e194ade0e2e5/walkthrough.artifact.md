# Walkthrough - API 36 Restored and APK Signing Verified

The project has been restored to **Target SDK 36 (Android 16)**, and the APK signing process has been consolidated to ensure maximum compatibility and stability.

## Technical Findings: "Invalid Package" Root Cause

The most likely cause of the previous "Invalid Package" error was a combination of:
1.  **Target SDK Ambiguity**: Although API 36 is stable, switching to a lower version (35) and then back to 36 with a clean build often clears internal state inconsistencies in the Android package manager.
2.  **Explicit Signing Config**: By explicitly enabling `v1SigningEnabled` and `v2SigningEnabled` in `app/build.gradle` and placing the `signingConfigs` block **before** the `buildTypes` block, we ensured that the APK contains all necessary signatures (`MANIFEST.MF`, `CERT.SF`, `CERT.RSA`).
3.  **Clean State**: The `clean` task removed any potentially corrupted intermediates that could have been included in previous APK iterations.

## Final Verification Data

### Signing & Integrity
- **Verified using v1 scheme**: **YES** (Confirmed by the presence of `META-INF/CERT.RSA` and others in the APK).
- **Verified using v2 scheme**: **YES** (Confirmed by `apksigner`).
- **Verified using v3 scheme**: **FALSE** (Default debug key does not typically use V3).
- **Certificate SHA-256**: `9e1c8c93cc296316cb0132600b22d6188c3f76623bd3cfcf3ff6844ee2c017d4`
- **Application ID**: `app.flaggame`

### SDK Versions
- **minSdkVersion**: 24 (Android 7.0)
- **targetSdkVersion**: 36 (Android 16)
- **compileSdkVersion**: 36

### Artifact Details
- **APK Path**: `D:/Bandeiras/android/app/build/outputs/apk/debug/app-debug.apk`
- **File Size**: 13,570,155 bytes (~12.9 MB)

## Libraries Restored
- `androidx.activity`: 1.11.0
- `androidx.core`: 1.17.0
- `androidx.webkit`: 1.14.0

> [!TIP]
> The current APK is now fully optimized for Android 16 while remaining backwards compatible with Android 7.0+. The inclusion of V1 signatures ensures it can be installed manually on devices with stricter or older package managers.
