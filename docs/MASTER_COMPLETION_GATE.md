# SanSeth Play — real player source comparison and release gate (2026-11-17)

Base: `SanSeth-Play-v0.1.0-REAL-IPTV-RECENTS-COMPAT-SOURCE.zip`.
This development batch adds **authorized Xtream API sign-in, persistent secured account, Live/Movie/Series catalogs, categories, search and episode selection using the existing PlayerView**, plus injectable HTTP mock tests. It does **not** claim that all Xtream providers share the same schema, that DRM works, or that any device release has passed.

## Research references

- https://github.com/4gray/iptvnator — multi-provider browsing, catch-up, VOD, recent, guide; feature inspiration only, no source copied.
- https://4gray.github.io/iptvnator/features/ — platform-specific support comparison.
- https://pub.dev/documentation/media_kit/latest/ — Flutter Media/Player APIs, headers and tracks.
- https://docs.flutter.dev/deployment — Flutter platform release requirements.

## What this batch actually supports

- Credential-validated Xtream account; secure storage; manual logout removing saved account.
- Live channels and VOD films via provider's `player_api.php` catalog endpoints.
- Series list and provider-provided episodes; selecting an episode opens its media URL with the existing PlayerView.
- Read-only category filter/search, bounded network fetch with timeout and 12 MiB cap, rejects redirects for credential-bearing API calls.
- Invalid media identifiers and extensions rejected rather than concatenated into arbitrary URLs.
- Existing M3U, offline cache, EPG, artwork, original player controls and Windows/Android scripts preserved.

## Important safety and capability limitations

- Xtream credentials are embedded in provider-specific playback URLs (required by this protocol). Never include raw URL or credentials in logs, crash reports or share sheets. A malicious provider or player engine could receive them; use only authorized trusted providers.
- HTTPS is recommended. If provider accepts only plaintext HTTP, network exposure remains possible: app does not automatically make HTTP secure.
- Account remains on device, no cross-device cloud sync. Clear app data or uninstall may remove it.
- Provider server types and stream extensions vary. Movie/series support depends on the provider and codecs.
- No DRM key acquisition, Stalker MAC emulation, recording, timeshift, catch-up, download manager, casting, multiview, true Android MediaSession, native TV remote hardware verification, or Windows MSIX signed installer in this batch.
- Flutter SDK, Android devices and Windows MSVC environment unavailable in this container; `flutter analyze`, `flutter test`, release APK/EXE and device installations **not executed**.
- Current code is **not production certified**. Final release requires source builds on Windows and playback/remote/overflow testing on mobile and real TV hardware.

## Acceptance test plan

1. `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1 -DeviceSerial "<phone-serial>"`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "<TV-IP:ADB-PORT>"`
4. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1`
5. Verify logged-in catalog/episodes against a **licensed test provider**, app restart/relogin/logout, 10-day offline cache, stale expiry, simultaneous remote input, stream errors, audio/subtitle/EPG, Android PiP, full-screen rotation, TV Back navigation.
6. Run golden tests at 320x568, 360x640, 720x1280, 1280x720, 1920x1080 and Windows resizable widths. Fail build on render overflow, exceptions, hangs or missing assets.

No universal claim of every IPTV player feature being implemented is made: third-party source formats, platform hardware and providers have distinct limitations.
