# SanSeth Play — Consolidated safety batch (2026-11-17)

Base: `SanSeth-Play-v0.1.0-CONSOLIDATED-RECORDING-WINDOWS-EXPORT-SOURCE.zip`.
App version remains `0.1.0+1`; approved original branding and build/install scripts are unchanged.

## Implemented in this source
- Recordings Library accessible from main overflow menu on Android mobile, Windows desktop, Android TV.
- Async listing (newest first) restricted to app-owned `SanSeth-<timestamp>.ts` and `SanSeth-HLS-<timestamp>.ts` files in application documents.
- Tap a recording to play it in the existing media_kit player as local VOD (no provider login).
- Context menu for Share/Export and confirmed Delete; deletion is scoped to the same application folder and rejects symlinks.
- Bound library UI height/width and use ellipsis + a single compact overflow menu to reduce small-screen overflows.
- Reject malformed HLS media sequence and discontinuity/gap/skip/variable tags, avoiding unsupported TS concatenation cases.
- Added regression tests for recordings listing, deletion scope and invalid HLS manifest tags.

## Not complete / not verified
- Google Cast is not implemented. Google Cast requires Android Cast Sender SDK, discovery UI, session lifecycle, compatible receiver and physical device. No fake working Cast action is exposed. In particular, credential-bearing IPTV URL handoff must be security-reviewed.
- Full live timeshift/DVR ring buffer is not implemented. Existing provider catch-up and bounded recordings are not a timeshift engine.
- Low-disk-space preflight, recording interruption recovery and native Android share-provider compatibility require device verification.
- Android 12+ native splash is system controlled; original full artwork is shown on the Flutter startup scene. Full OS-native 9:16 splash is not technically guaranteed.
- Windows desktop media keys and installer scripts are present from base; their actual runtime/installer sign-off is pending.
- Flutter and Dart SDK, Windows C++ build tools, connected Android phone/TV and Chromecast devices are not available in this environment. No compilation, API integration test, APK/EXE build, or hardware performance pass is claimed.

## Real-world verification gates
1. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`.
2. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1` with an authorized connected phone.
3. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1` with Flutter, VS desktop workload and Inno Setup installed.
4. Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:PORT"` with a paired TV.
5. Check recordings library on 320px phone, resizable Windows, Android TV D-pad, unreadable/removed TS file, export/share, delete, storage full and multi-hour streaming.
6. Do not ship until all tests pass and unfinished casting/timeshift are either implemented and verified or explicitly excluded from release scope.
