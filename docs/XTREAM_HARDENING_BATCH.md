# Xtream optional provider hardening — SanSeth Play v0.1.0+1

## Exact source changes

- `lib/core/xtream_client.dart`: moves 12 MiB-bounded provider JSON decoding into Flutter `compute()` background isolate, preventing synchronous decoding on the UI isolate (on the targeted Android/Windows platforms).
- `lib/app/xtream_browser.dart`: session/generation guards for saved-login restore, authentication, catalog fetch, episode fetch, logout and disposal; stale responses cannot paint catalog after session changes.
- `test/xtream_client_test.dart`: deterministic local HTTP mock tests for a 2,500-channel response and refusing credential-leaking redirects.

## Preserve

- M3U/GitHub playlist import without sign-in
- Direct streaming URL without sign-in
- Optional provider login only on explicit request, with Live TV, Movies, Series
- Existing original gold-S logo / splash / launcher art
- Existing Android Mobile, Windows and Android TV one-line scripts

## Production verification gates

No Flutter SDK or physical Android/Windows/TV devices were available in the authoring environment. Tests are added but not executed. On Windows with Flutter and VS Build Tools:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "YOUR_TV_ADB_SERIAL"
```

Still missing: full catch-up/DVR, native Android MediaSession, Chromecast, real multiview, native splash sign-off and physical performance/codec tests. No production certification is asserted.
