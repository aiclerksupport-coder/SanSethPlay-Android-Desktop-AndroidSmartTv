# SanSeth Play — Consolidated Pending Modules Implementation & Truth Report

Version preserved: `0.1.0+1`. Source base: `SanSeth-Play-v0.1.0-RECORDING-BRANDING-DEV-SOURCE.zip`.

## Implemented in THIS checkpoint

1. `lib/core/hls_ts_recorder.dart`: bounded live/VOD MPEG-TS HLS media playlists with UTC-stamped `.ts` output; de-duplicates sliding live segments via `EXT-X-MEDIA-SEQUENCE`, rejects encrypted/DRM, variant/master, byte-range, fMP4/LL-HLS and credential-bearing segment URLs. HTTP redirects disabled, per-resource time/size limits, 1 GB/60-minute session cap, user Stop support. This is **recording**, not disk-backed DVR/timeshift.
2. `lib/core/direct_ts_recorder.dart`: user Stop no longer treats expected socket closure as an error deleting an otherwise valid partial recording.
3. `lib/player/player_view.dart`: Record/Stop supports direct `.ts` and supported `.m3u8` TS media playlists; Share/Export dialog for completed recordings, safe fallback when OS share target unavailable; retains source audio/subtitles, Next/Previous, EPG, etc.
4. `lib/player/windows_media_session.dart`: Windows SMTC Play/Pause/Next/Previous/Stop connected to primary player, safely non-blocking if native bridge fails; secondary multiview has media-session opt-out.
5. `test/hls_ts_recorder_test.dart`: manifest compatibility and rejection tests written, **not executed**.
6. `pubspec.yaml`: add `smtc_windows: ^1.1.0` and `share_plus: ^13.3.1` (need Flutter dependency resolution).

## Uncompleted modules — do not describe these as working

- Google Cast receiver discovery, Android sender SDK Cast sessions and authenticated media handoff. Needs Google Play Services/Cast-capable hardware, native sender SDK & device acceptance. Passing raw URL to another app is NOT equivalent.
- Disk-based timeshift/DVR buffering, rolling retention, HLS AES key handling (not included intentionally), DASH and fMP4 recording. Depends on content rights and backend manifest format.
- Android TV Recordings gallery with SAF/MediaStore durable export, device recording quota/free-space checks. Current Share/Export intent only.
- Android 12+ OS splash full-artwork sign-off: OS controls system splash shape; app-branded launch scene preserves full approved artwork afterwards.
- Windows Inno Setup installer signing, installer clean-machine execution, Windows desktop integration QA.
- Native MediaSession/codec/stream compatibility under physical Android mobile, Windows and Android TV hardware; zero-overflow, D-pad and multiview decoder stress testing.

## Release gates (must run on user's Windows build host)

- `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:DEBUG_PORT"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`

All native & runtime results currently **NOT VERIFIED**: this environment lacks Flutter/Dart toolchains, Windows build tools, Android/TV hardware, Google Cast receiver. Never conflate ZIP integrity/static audit with compilation or playback.

## Security & compatibility notes

- HLS manifest segments are only accepted when plain MPEG-TS, HTTP(S), no embedded userinfo, no redirect, not encrypted.
- Recording source URLs may contain query authorization tokens. They are never placed into user-visible errors or filenames. Share only saved output files, and only after explicit user action.
- HLS recording supports a *media playlist URL*, not an HLS multivariant master. Output is TS and not remuxed to MP4.
- `Stop` after a segment completes can take up to one polling interval to finalize; cancellation aborts in-flight HTTP requests.
- Recording uses app documents and limits gross byte count/duration. Free-space precheck, file durability/backup policy and Android scoped-storage export require device QA before release.
