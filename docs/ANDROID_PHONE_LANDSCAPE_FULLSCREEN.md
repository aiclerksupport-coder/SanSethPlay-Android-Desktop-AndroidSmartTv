# SanSeth Play v0.1.0+1 - Android mobile landscape player

## Implemented source behavior

- Auto-rotate remains owned by Android. No forced landscape on app startup.
- On Android phones (shortest logical display edge < 600), active playback + landscape switches to immersive fullscreen. No channel selected = normal responsive browsing.
- Rotating back to portrait restores regular navigation. Windows/Desktop and Android TV bypass mobile-only orientation policy.
- The PlayerView remains in the same first Stack child through orientation updates, to retain decoder/video state, media-session, current channel and timeshift state rather than forcibly reopening the stream.
- Fullscreen controls: Channels/Search opens a responsive modal sheet, My Playlists, More (TV guide, Recordings, Xtream, Favorites), Exit Fullscreen, while player retains its Aspect cycle and player-settings toolbar.
- Search field keyboard focus is released on immersive transition. A modal already open remains open on rotation; the underlying duplicated sidebar is not built until its sheet closes.
- Exit Fullscreen keeps a landscape browsing layout without forcing device orientation; rotating to portrait resets that user override.
- System UI is restored to edge-to-edge when exiting immersive and on HomeScreen dispose. The generated Android runner now uses native WindowInsetsController (API 30+) or legacy decorView flags (older devices) because Flutter system UI immersive mode may be ignored with Android 15+ edge-to-edge targets. A Dart fallback remains for older runners.

## Required real-device acceptance

1. With Android auto-rotate ON, play a long-running M3U channel in portrait; rotate to landscape. Verify that fullscreen starts without restarting decoder/audio or losing seek/recording state.
2. Use Next, Previous, Aspect cycling, player settings, and Channels sheet. Close sheet, rotate back portrait, verify the same selected channel and search filter are retained.
3. Open Channels sheet and then rotate portrait without closing it. Verify no duplicate FocusNode exception and sheet remains usable. Try select a channel.
4. Rotate while Add Playlist / TV Guide / More dialog is open and verify input contents and navigator stack persist. Close the dialog; verify correct underlying layout.
5. With no channel selected, rotate: navigation stays available and no blank fullscreen black screen appears.
6. Enable rotation lock from player settings; verify Android honors lock and unlocking restores normal rotation.
7. Run test widget sizes 320x568, 360x640, 800x360, 915x412, 800x480, 1024x768 and 1920x1080; verify no overflow. Test text scale 1.0, 1.5 and 2.0 manually.
8. Windows and Android TV: verify no immersive mode, no portrait-specific changes, D-pad and keyboard controls remain working.

## Validation limits

These are source-level changes. Flutter SDK and connected Android test hardware are not available in the packaging environment; Flutter analyze/test/release build and physical rotation/playback verification are NOT claimed passed.

## One-line test and build

`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`

`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1`

`powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1`

GitHub push remains gated by successful required tests/install verification.
