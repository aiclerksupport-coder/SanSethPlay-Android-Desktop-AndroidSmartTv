# Android lint release failure - targeted repair

Base: `SanSeth-Play-v0.1.0-NINE-FLUTTER-TEST-FIX-SOURCE.zip`
Version: `v0.1.0+1` (unchanged)

## Log-based root cause

`07_build_android-mobile` failed at `:app:lintVitalRelease` because generated `android/app/src/main/res/xml/network_security_config.xml` omits `includeSubdomains` on the `127.0.0.1` and `localhost` entries. The other Gradle/Kotlin warnings are not the fatal release blocker in this log.

## Changes

- `tool/prepare_platforms.ps1`: add `includeSubdomains="false"` to both existing domain nodes in the XML generator.
- Same script: fail-fast generated-XML verification for exact loopback hosts and cleartext restrictions.
- No Flutter/Dart, tests, assets, native Kotlin, Gradle or app version changes.

## Security invariant

`base-config cleartextTrafficPermitted="false"` remains unchanged. Only existing loopback DVR hosts allow cleartext. No global HTTP permission or lint suppression is introduced.

## Verification performed

- ZIP integrity: validated.
- Extracted XML: parsed with Python XML parser; expected domain attributes asserted.
- Byte-level base comparison: only the stated PowerShell generator changed; this document is new.

## Not yet verified

- Windows PowerShell 5.1 execution of preparation script and `:app:lintVitalRelease`/APK build: require Windows Android SDK/Gradle toolchain.
- Install, launch and playback still require devices.

## One-line build

`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`

Device connection is not needed to compile; installation will detect it after build. Do not push until build and required checks succeed.
