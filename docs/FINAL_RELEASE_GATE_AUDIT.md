# SanSeth Play — Targeted release-gate patch

Source base: `SanSeth-Play-v0.1.0-LIVE-TIMESHIFT-DVR-DEVELOPMENT-SOURCE.zip`.

- Original files: **127**
- Byte-for-byte unchanged: **122**
- Modified: **5**
- Added: **2**
- Removed: **0**
- Approved branding assets untouched: **True**

## Changed existing files
- `lib/core/hls_timeshift.dart`
- `lib/core/hls_ts_recorder.dart`
- `lib/player/android_cast.dart`
- `test/cast_url_test.dart`
- `test/hls_timeshift_network_test.dart`

## Added files
- `VERIFY_ANDROID_LAUNCH.ps1`
- `VERIFY_WINDOWS_LAUNCH.ps1`

## What was validated here
- ZIP archive extraction and baseline SHA-256/byte-equivalence.
- Source-presence checks for integrations and regression tests.
- Python-driven structural/static checks only; **not** Flutter compilation.

## What was NOT validated here
- Flutter analyze/test and native Gradle/CMake/Inno Setup builds: Flutter/Windows tooling unavailable in this container.
- Physical Android phone, Android TV, Chromecast, Windows playback, decoder, remote, native splash, installer execution and performance: devices/toolchains unavailable.

## Final feature-gate status (do not claim PASS without results)
- Google Cast sender: Android code exists; receiver playback/cast session **UNVERIFIED**. Windows sender **NOT IMPLEMENTED**.
- HLS timeshift: TS-only bounded source + new packet/safe-read hardening; decoder seek/live-edge **UNVERIFIED**.
- Android recording recovery: partial-file recovery source exists; low-storage real interruption **UNVERIFIED**.
- Windows media controls: code exists; physical media-key test **UNVERIFIED**.
- Splash: original assets preserved; Android 12+ OS splash and full branded in-app launch **UNVERIFIED**.
- Windows installer: build script exists; installer execution/signature **UNVERIFIED**.
- Three platforms: no actual APK/EXE or device performance verification completed.

## Safety conditions before public launch
1. Run full three-platform build/test scripts and post-install launch checks.
2. Test 1-hour TS/HLS streams, channel switching and DVR sliding-window eviction on Android/Windows/TV.
3. Validate public HTTPS casting on a real receiver; reject authenticated sources and verify end-session.
4. Check app memory, jank, D-pad focus, high-volume warning, storage-full and recovery cases.
5. Sign Android APK and Windows installer, then perform fresh/upgrade installs on clean devices.
