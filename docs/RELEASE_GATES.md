# SanSeth Play - release gates

Do NOT market this foundation as a production-complete media player.

## Automated gates on a Windows Flutter workstation
1. `flutter pub get`
2. `dart format lib test`
3. `flutter analyze --no-pub`
4. `flutter test --reporter expanded -j 1`
5. `flutter build apk --release`
6. `flutter build windows --release`

## Manual device gates
- Android mobile: 320dp, 360dp and tablet sizes; landscape, orientation changes, back navigation.
- Android TV: D-pad focus, BACK, center/OK, accessibility, launcher banner, cold startup, buffering, remote search input, 1080p/4K devices.
- Windows: window resize 800x480 to maximized, keyboard Ctrl+O/Ctrl+F, playback, DPI 100%/150%/200%, taskbar and multi-monitor.
- Native Android 12+ splash is OS constrained; verify the S icon and black background on physical devices; the full 9:16 logo can be shown in an in-app branded launch view later.
- HTTP and HTTPS network playback, unreachable endpoints, expiring stream token, 8 MB rejection, 20k M3U entries, memory use, sustained playback.
- URL credentials must never be logged and must not be included in crash telemetry.

## Not implemented yet
- Full EPG timeline/auto-refresh, catch-up and recording, Xtream, DRM, PiP,
  multiview, mature Android TV focus UX, in-app 9:16 splash, native Windows
  installer, telemetry and field performance measurements.
- Verify SQLite FFI packaging and OS secure storage on Windows before release.
- Verify on actual devices that saved channel snapshot survives 10+ days offline
  and that it fails safely if encryption keys become inaccessible.
