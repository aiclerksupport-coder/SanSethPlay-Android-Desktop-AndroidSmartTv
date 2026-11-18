# SanSeth Play v0.1.0+1 — Premium Experience Candidate

This is a source-only candidate against the user's original `WINDOWS-PREFLIGHT-LANDSCAPE-PLAYER-CONTROLS-FIX` archive. The Flutter package version intentionally remains `0.1.0+1`.

## Changed
- My Playlists modal: searchable, expanded cards; per-row Edit (name + URL) and Delete, both persisted via existing encrypted secure storage; URL duplicate validation; delete confirmation; invalidates stale cached channels on URL change.
- Last-watched channel: stores last channel and owning saved playlist in secure storage. When launching, load the preferred playlist and reselect channel only if present in cached or updated channel list. Removed playlists do not auto-resume.
- Background: Flutter lifecycle no longer calls `pause()` merely for opening another app. Android native Activity requests PiP when Home/app switch happens while playback is active, if the device supports PiP. On Android actual background audio/video continuity depends on OS, battery, audio focus and Picture-in-Picture support. **No foreground playback service added**; long-lived background playback under process termination is NOT guaranteed.
- Live playback: modest libmpv cache tuning and no intentional initial cache pause (best effort, stream and server latency remain variable).
- Theme: premium midnight navy/gold cards, larger rounded controls, updated dark dialogs and navigation, clearer mobile list rows. Responsive Flutter UI source shared by Android Mobile, Android TV and Windows.

## Required acceptance tests (not run in this environment)
- `dart format .`, `flutter analyze`, `flutter test -j 1`
- Android Mobile release build + ADB install; verify foreground/background audio, PiP supported device, home/restart last channel, edit URL, delete active/inactive playlist, 20 rapid switches, landscape controls.
- Android TV release build + physical Mi TV remote navigation + playlist management focus, return from HDMI/home, audio focus and last channel.
- Windows build + installer/launch + minimize/restore playback, source persistence and keyboard navigation. Visual Studio C++ toolchain required.
- Measure first-frame time per channel on same Wi-Fi as reference player; don't claim instant play for slow servers, broken streams or long HLS segments.

## Validation boundaries
- Native Android & Windows folders are prepared by the existing `tool/prepare_platforms.ps1` before builds; this source ZIP intentionally preserves that baseline layout.
- This candidate **has not been compiled** because Flutter/Dart/Windows toolchains and target devices are unavailable in this sandbox.
- Do not push to main or publish APK before above tests pass.
