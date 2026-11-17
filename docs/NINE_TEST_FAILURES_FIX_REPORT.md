# 9 Flutter Test Failures: Targeted Repair (Hinglish)

Original base: `SanSeth-Play-v0.1.0-37-ANALYZER-BRACES-FIX-SOURCE.zip`
Version unchanged: `v0.1.0+1`. App logic, assets, and scripts unchanged.

## Root cause
- `hls_timeshift_network_test.dart`: Explicit `TestWidgetsFlutterBinding.ensureInitialized()` causes Flutter's HTTP override to force HTTP 400, so local loopback server cannot be reached. Remove widget binding in these non-widget tests. The tests still exercise the real loopback DVR server and MPEG-TS rejection.
- `responsive_sizes_test.dart` and `widget_smoke_test.dart`: Tests expected `CHANNELS` before the 650 ms branded splash had finished. Advance the fake clock 700 ms and pump the resulting HomeScreen frame; then assert the real CHANNELS content and no framework exception. The production splash timing remains exactly as before.

## Verification
Static checks and ZIP CRC were performed. Flutter SDK, Windows VM, and hardware are unavailable in this environment; analyzer, test and APK success remain unverified.

## One-line commands
`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`

`flutter test --reporter expanded -j 1 test/hls_timeshift_network_test.dart test/responsive_sizes_test.dart test/widget_smoke_test.dart`

Any failure should retain the existing failure-only verbose logs. GitHub push remains blocked until gates pass.
