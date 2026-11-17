# SanSeth Play — v0.1.0+1

SanSeth Play is a Flutter IPTV/M3U media player for user-provided, authorized media sources. Android Mobile, Android Smart TV and Windows Desktop share the Flutter UI; native build/installation must be verified separately.

## New UI and playback workflow

- Home offers direct M3U/GitHub URL, direct live stream and pasted M3U entry points.
- Header uses original golden emblem over the application background, with larger icon and direct Import action.
- Phone portrait has Home / Import / Channels navigation. Android TV keeps the directional-focus layout; desktop retains the wider sidebar.
- With a selected channel, tap the mini-player icon next to its name or choose Channels on the mobile navigation bar. The playing video moves to a bottom-right floating mini-player without intentionally creating a second decoder. Tap restore to expand, close to stop, or select another channel to switch the same player.
- About / Version displays installed package version and developer **Kalpesh Patel**. Available in More options.
- Full approved 9:16 portrait splash artwork is shown during Flutter app startup. Android 12+ OS splash is controlled by Android and displays a constrained app icon first; it cannot reliably show a full-bleed portrait background.
- How to use is accessible from More options, with real instructions for importing and mini-player navigation.
- Only implemented import modes are shown: M3U/GitHub URL, direct stream URL, and paste M3U text. A native-device M3U file picker is *not* claimed as implemented in this checkpoint.

## Release commands (PowerShell)

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1
```

Device is needed only at install stage, not during Flutter analyze or compilation. Test Flutter SDK, Gradle, TV remote, Windows C++ toolchain and actual playback on each target before GitHub push. The build and install gate must pass; ZIP integrity does not prove runtime correctness.

## Source/license documents

See LICENSE, PRIVACY.md, TERMS.md, SECURITY.md and THIRD_PARTY_NOTICES.md. These are project notices/drafts for owner review, not a claim that all third-party license and codec redistribution obligations have been satisfied. Public release requires a full dependency license scan and owner sign-off.

---

## Historical project notes

# SanSeth Play — v0.1.0+1 Playlist Persistence Batch

Premium Flutter IPTV / M3U player for authorized streams. Shared design system for **mobile, desktop, Android TV**. One original brand identity; no bundled TV channels or copyrighted playlists.

## Included and working source
- Responsive mobile/desktop/tv-preview layout, overflow-safe text and bounded lists.
- User-provided M3U playlist URL or pasted M3U; strict HTTP(S) URL validation, 8 MB limit and 20,000-item cap.
- Parser runs in `compute` isolate. Stream playback via media_kit and basic adaptive controls.
- Original approved logo and separately prepared original-artwork icon/splash assets.
- Unit tests for M3U parser and widget smoke tests (not yet run in this environment).

## Three target platforms (Windows build host)

**Android Mobile + Android Smart TV** share the Android APK, and **Windows Desktop** has a separate desktop build. Install Flutter stable, Android SDK and Visual Studio Desktop Development with C++ workload. Extract this ZIP and run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\BUILD_ALL.ps1
```

The included `tool/prepare_platforms.ps1` creates real native Flutter wrappers and adds Android internet permission, optional touchscreen/leanback features, a Leanback launcher entry and the original-brand TV banner. `BUILD_ALL.ps1` then formats, analyzes, tests and builds an APK and Windows release. Both scripts fail if a build step fails.

Run directly for development with `flutter run -d windows` or `flutter run -d <android-device-id>`. Use the built APK on authorized Android TV hardware and test with a physical D-pad remote. TV and mobile use the **same Android application ID** by default; do not attempt to install both separately on one device.

**Important**: native wrappers are generated on your PC because the current environment has no Flutter SDK; binaries are **not** bundled in this ZIP. The Leanback manifest does not itself guarantee polished D-pad navigation on every TV model. Splash artwork is prepared but native splash integration and final per-OS icon packaging still need hardware validation. HTTPS streams are the default safe option; for HTTP streams, an Android network-security policy may be required and should be configured for authorized sources only.

## Scope and security boundaries

- Current version is a **functional starter**, not production-complete IPTV software. Saved URL sources are persistent but channel listings are downloaded when selected or reopened; offline cached channel listings, EPG, Xtream credentials, catch-up, DRM, downloads, PiP, or multi-view are pending.
- `media_kit` playback depends on target device native codecs and media format; test Android TV hardware and desktop platforms individually.
- The network importer allows user-supplied HTTP(S) URLs; enterprise hardening should add private-network/redirect controls where applicable, platform certificate enforcement and sensitive URL handling.
- User is responsible for playback rights to added streams.
- Before publishing, audit native library license/redistribution terms and perform trademark checks.

## Brand master rules

- `assets/branding/full_logo_original.png`: exact approved original source.
- `assets/branding/app_icon_master.png`: S/play symbol only, without wordmark.
- `assets/branding/splash_portrait_1080x1920.png`: full original wordmark, uncropped and centered.
- `assets/branding/splash_landscape_1920x1080.png`: same logo centered for landscape screens; no distortions.
- Do not redraw, recolor or stylize the original logo.

## Actual validation

Flutter SDK is **not installed in the generator environment**. `flutter analyze`, `flutter test`, Android/Windows builds, native splash display and physical hardware performance remain **unverified**. See `docs/NEXT_STEPS.md`.

## v0.1.0 continuation changes (same app version, additional foundation work)

- Categories/group filter, star favorites and favorites-only view, search debounce, keyboard arrows and Ctrl+O/Ctrl+F, and clear playlist action.
- Favorites are persisted as SHA-256 identifiers rather than plaintext stream URL credentials; playlist text and remote playlist URLs are session-only (not persisted). Favorites become visible again when the same playlist is reimported.
- The first channel no longer auto-plays after playlist import: playback starts only after deliberate selection.
- Bounded flexible preview, 320px-to-TV responsive smoke sizes, favorite security test, player error subscription cleanup.
- Android launcher assets prepared from the *approved* S emblem, original-wordmark launch asset and Android TV banner integrated into Windows platform setup script.
- Android 12+ system splash uses an OS-controlled app icon; the 9:16 branded full artwork must eventually be presented as an in-app launch scene. Do not advertise Android 12 native full-screen 9:16 as completed.
- See `docs/RELEASE_GATES.md` for gaps and release/hardware test gates.

**Build status of the continuation:** Static source assembled; Flutter/Dart, Gradle and physical TV runtimes are not available in this environment. Therefore analysis, tests, binaries and real-device verification are pending. Do not equate included tests with passed tests.

## New: saved playlists and direct live stream URLs

- Add a URL using **Add Playlist → M3U URL / GitHub Link**, **Direct Live Stream URL**, or temporary **Paste M3U Text**.
- Public GitHub `/blob/<branch>/<file>.m3u` page links automatically normalize to raw file URLs. `raw.githubusercontent.com` links also work. Branch names with slash may need a direct raw URL.
- Direct stream mode creates one playable channel for `.m3u8`, `.mp4`, `.ts`, etc. A remote URL ending `.m3u8` is treated as one HLS playback stream, not as a list of channels (because HLS playlists contain segment records).
- Remote HTTP(S) M3U URLs are saved BEFORE network retrieval, so even a failed download won't discard the saved entry.
- Saved sources survive app restarts via `flutter_secure_storage`, rather than plaintext preferences. On startup the first saved playlist is downloaded again; switch using library icon, refresh using rotating arrow, or remove the selected saved entry using trash icon.
- Supports up to 100 saved source references, 8 MB max fetched M3U size, 20,000 parsed channels, four safe HTTP redirects; HTTPS-to-HTTP downgrade redirects are refused.
- Favorites still store only one-way stream hashes, not URLs.
- **Offline caveat:** saved source references remain visible, but fetched remote channel lists are NOT yet cached for offline viewing. Your stream URL can be saved even when playback host is offline; actual video always requires a reachable stream. Content from paste-text mode remains session-only by design.
- **Security caveat:** user-supplied HTTP URLs are allowed for compatible legacy devices, but HTTPS is preferable; Android cleartext policy and streaming engine behavior require real-device verification. Private IP/loopback protection, EPG, secure offline cache, native OS splash, TV remote focus traversal and codec device testing are future release gates.
- **Storage caveat:** deleting app data or uninstalling removes saved playlists. Same playlist records do not automatically sync across your three devices. For cloud sync, the project needs an account and end-to-end encryption/key recovery design.

### Real-world risks and next-version fixes

1. **Remote source may expire/redirect:** save source independently, show a retry control and do not discard it on failure. This is implemented. Retry loops, rate-limit handling and scheduled refresh are not.
2. **Credentials in URLs:** source URLs can include signed tokens. Secure storage is used instead of shared preferences. Screen capture, clipboard hygiene and OS backups remain important; disable Android automatic backup until secure recovery is designed.
3. **Concurrent add/remove/refresh:** serialized writes protect order; UI prevents overlapping imports. Hardware key spam and process kill durability testing are pending.
4. **10-day offline startup:** source references survive, but channel listings require connection. Next-version strategy: encrypted, bounded, atomic cache per playlist; show cached channels immediately, refresh with ETag/If-Modified-Since in the background, reconcile channel identity by provider ID plus normalized URL, and never overwrite cache with an empty/error download.
5. **Memory/large playlists:** 8 MB input and 20,000 channel cap, `compute()` parser and `ListView.builder` bound work; for truly huge lists, add streaming parser and incremental filtering benchmarks.
6. **TV D-pad/focus:** generic Flutter focus shortcuts are insufficient for production TV UX. Explicit focus graph, visible focus-ring, Back/Select testing on actual remotes required.
7. **Build acceptance:** tests are included but not executed here; run `BUILD_ALL.ps1` with Flutter SDK, Android SDK, and Windows C++ tooling before calling it verified.

## Offline + EPG + TV continuation batch

See `docs/IMPLEMENTATION_AUDIT.md`. This batch adds bounded encrypted channel snapshots and XMLTV now-playing, focus navigation and small-window menu. XMLTV program data and URL are session-only. Android/Windows/TV verification and advanced player features remain pending.


## Advanced Player Batch (same app version v0.1.0+1)

- **Encrypted SQLite last-known-good channel snapshots**: Android native SQLite,
  Windows SQLite FFI, AES-256-GCM authenticated blob, separately secured key,
  gzip compression on a background isolate, atomic per-playlist replace, and
  migration from the prior secure-storage snapshots. Handles up to 20,000 M3U
  channels / 32 MiB JSON snapshot, rather than silently losing entries above 1,500.
- **TV Guide UI**: XMLTV channel matching using `tvg-id`, searchable and lazy
  NOW/NEXT cards, user-selectable channel playback and a bounded modal that
  adapts to mobile, desktop and TV sizes. XMLTV URL fetch is still manual;
  full timeline/calendar and automatic EPG cache are not included.
- **Playback resilience**: bounded retry delays (2/5/12 seconds), manual
  retry button, stream error feedback, subscription/timer cleanup on dispose.
  Unsupported codec, bad stream and DRM-protected content are not fixed by retry.
- **Brand safety**: original S emblem, lockup, launcher art and native splash
  image bytes are preserved verbatim.

### Honest verification status
Flutter SDK is not installed in the authoring environment. Run BUILD_ALL.ps1
on a Windows machine with Flutter, Dart and Visual Studio desktop C++ tooling.
The added source and widget tests are NOT yet executed here, and mobile/TV
hardware UX, Windows native SQLite packaging, SQLite keychain restore and
video codecs require physical runtime validation before any public release.

### Known unimplemented production work
Full cross-device sync, Xtream login, DRM, PiP, multiview, catch-up TV, EPG
persistent refresh and programme timeline grid, standalone native TV focus
traversal audit, Windows MSI installer and native Android 12+ full-logo
in-app launch scene. Streaming access is limited to user-authorized sources.

## EPG Offline + Compressed Feeds Development Batch (2026-11-17)
- Supports ordinary XMLTV `.xml` and gzip encoded `.xml.gz` responses (detected by gzip magic bytes) in a background isolate.
- 8 MiB maximum network XMLTV download, 32 MiB expanded-size validation, first 12,000 programme elements parsed; intentionally bounded for device memory.
- Successful EPG updates are gzip-compressed, AES-256-GCM authenticated/encrypted and committed atomically to `sanseth_epg_v1.sqlite`; encryption key remains in platform secure storage.
- Saved EPG source now restores its last-known-good programme schedule before attempting network refresh. Failed network fetch keeps the prior schedule.
- Guide source switch no longer displays an older source fetch result, and queued refresh is scheduled after any active refresh finishes.
- Added `test/epg_offline_codec_test.dart` for plain vs gzip XMLTV, damaged gzip and encrypted-cache payload codec recovery.

### Known limitations and important verification
- `gzip.decode()` expands compressed bytes before validating expanded length. Do not treat this implementation as safe against adversarial gzip bombs. A streaming bounded inflater is still required for untrusted large feeds.
- Existing XMLTV parser stops at 12,000 programme elements, and no programme expiry retention policy has been added.
- Cache at rest is encrypted; URL remains secure-stored. Cross-device cloud sync is not included.
- Flutter SDK is absent in the artifact environment: `flutter pub get`, `flutter analyze`, `flutter test`, Android APK, Windows release and Android TV hardware testing have NOT been run. Source should be compiled and tested before release.

## Master controls development batch (2026-11-17)
- Playback remains `media_kit` + `media_kit_video` (Android/Windows), preserving original logo and prior playlist/EPG/cache code.
- Video overlay contains previous and next channel buttons (bounded, only when adjacent source channels exist), and a scrollable controls sheet.
- Play/pause, manual stream reload, +/-10-second seek for known-duration streams, mute and volume step/slider (0..200), explicit high-volume confirmation before software boost above 100, playback speed 0.5..2.0, Fit/Fill/Crop/Actual rendering, Android orientation lock, existing adaptive fullscreen button and keyboard handling.
- Unsupported/undetermined-duration LIVE streams do not pretend to support seeking; Android rotate-lock is disabled on Windows; actual audio gain above 100 is backend/device-dependent.
- These changes are **source level** only; Flutter SDK was not installed in the authoring environment. Hardware playback tests, TV D-pad traversal, background media session, subtitles/audio/video track menu, DRM, PiP, multiview, catch-up, all protocol/device compatibility and installer remain pending.
- Playback URLs may be signed/secret and should not be printed in logs.


## Next batch: Audio / Subtitles / Remote safety (source-only)
- Live `media_kit` tracks subscription, audio and subtitle selection, including Auto/Off tracks.
- External HTTP(S) SRT/WebVTT captions via user-entered URL with scheme/userinfo validation.
- Basic channel-change throttle (250 ms) to avoid excessive decoder recreation under rapid taps.
- New subtitle URL validation tests.
- All original approved branding assets preserved byte-for-byte.

**Security caveat:** HTTP is allowed for user-owned local-network streams but subtitle
content can be observed/modified on transit; prefer HTTPS. URL validation is not a
full SSRF/privacy policy. Disable automatic remote subtitle downloads for untrusted
providers if required. No credential or token URL is logged by this UI.

**Not verified:** Flutter SDK, release builds, TV remote hardware, real subtitle codecs,
PiP, cast, DRM and platform playback performance.

## TV remote / playback safety hardening batch (source-only)
- Player-scoped Flutter hardware key mapping: media play/pause, media next/previous, arrow seek on seekable sources, mute and volume. Handlers do not grab keyboard keys when player does not own focus. Device/OS may intercept hardware volume or media events first.
- Buffering state indicator uses the real `media_kit` stream; no fake loading progress.
- Transport commands are guarded against overlapping async execution; channel navigation retains the existing parent-side 250ms throttle.
- Volume changes are serialized; 100%+ requires once-per-player-session user approval, and the consent is never persisted. 200% remains backend-dependent and potentially unsafe.
- Mapping regression test added. No native Android MediaSession, OS background playback, PiP or DRM claimed.
- Flutter compile, full remote hardware and device tests still REQUIRED.

## Lifecycle and rapid channel switch safety continuation
See `docs/LIFECYCLE_BATCH.md` for new behavior, limitations, and unverified runtime acceptance.


## Three platform build / install pipeline

See `docs/BUILD_AND_INSTALL_HINGLISH.md` and separate one-line scripts:
`BUILD_ANDROID_MOBILE.ps1`, `BUILD_ANDROID_TV.ps1`, `BUILD_WINDOWS.ps1`, `RUN_ALL_TESTS.ps1`, `BUILD_ALL.ps1`.
All verbose terminal output visible; only failed steps generate saved diagnostic logs.
**Not production verified:** the provided environment cannot run Flutter, Android SDK/ADB or Visual Studio Windows C++ release builds.

## Real IPTV source comparison — recent/history batch

See [`docs/REAL_IPTV_SOURCE_GAP_AUDIT.md`](docs/REAL_IPTV_SOURCE_GAP_AUDIT.md). Added a Recent filter and local privacy-preserving last-40 playback identifiers, BOM/CR M3U parser compatibility, and no-drop navigation selection. This is source implementation only; Flutter SDK/runtime test not present in authoring environment. Existing one-line build/install scripts are unchanged.

## Xtream performance/safety hardening

See `docs/XTREAM_HARDENING_BATCH.md`. Optional Xtream stays optional; M3U and direct URLs do not require login. Catalog JSON parsing now runs in `compute()` and session-bound async responses cannot update a switched/disposed browser.

## Advanced continuation batch (same v0.1.0+1)
- Resume last VOD/movie/series position with token-safe hashed storage (no seek on non-seekable Live TV).
- Real dual-stream 2-channel multiview for imported M3U playlists (second stream muted).
- Optional signed-distribution-ready installer *build flow* for Windows with Inno Setup 6: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`. Windows Setup binary signing not included.
- Scope and unverified gates: `docs/PRODUCTION_PENDING_TRUTH.md`.


## Category-wise GitHub M3U import (v0.1.0+1)
Same M3U URL is saved once. The channel categories (`group-title`) appear under the saved playlist and are searchable; duplicates are rejected across source modes and GitHub blob/raw equivalents. Saved source picker and category picker use lazy lists. See `docs/CATEGORY_PLAYLIST_BATCH.md`.


## GitHub / one-line end-to-end pipeline

See `docs/GITHUB_BUILD_PUSH_HINGLISH.md`. GitHub push happens only after successful local tests, installs, and smoke checks.
