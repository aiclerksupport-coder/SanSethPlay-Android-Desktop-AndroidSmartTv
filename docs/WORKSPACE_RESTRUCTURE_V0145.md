# SanSeth Play v0.1.4+5 — Premium workspace restructure (Hinglish)

## Source and version
- Base: `SanSeth-Play-v0.1.4+5-PREMIUM-OTT-UI-ANALYZE-FIX-REPLACEMENT-SOURCE.zip`.
- App version `0.1.4+5` unchanged. No unrelated media/network/storage implementation changes.
- Features remain wired to existing service methods: M3U/GitHub playlist, direct HTTP(S), optional authorized Xtream, EPG, favorites, recent, recordings, temporary channel-health filtering, owner PIN/playlist privacy, multiview and player.

## New UI
- **Mobile portrait:** fixed player at top, compact current-channel strip, and separate `Home`, `Channels`, `Guide`, `Library`, `Import` bottom tabs. Only the workspace underneath scrolls; browsing does not scroll the player off-screen.
- **Home:** compact dashboard and quick tune, no giant full catalog embedded in the Home feed.
- **Channels:** existing full lazy ListView + playlist selection, categories, search, hide temporarily failed, favorites and recent filtering.
- **Guide:** entry to existing full TV guide, XMLTV load/refresh. No fictitious EPG data.
- **Library:** favorites, recent, recordings and saved playlists using the real existing actions.
- **Import:** M3U URL, direct URL, pasted M3U and optional authorized Xtream provider.
- **Wide screens:** left workspace navigation plus persistent right-hand video pane. Android landscape fullscreen player remains on existing pathway.
- **Keyboard:** video preview compacts while keyboard is visible; search input remains mounted; accessory filters collapse to make room for channel results.

## Safety decisions
1. Do not duplicate PlayerView or instantiate a decoder in each tab. A single `_content` subtree stays mounted above the mobile workspace.
2. Do not delete or overwrite playlists. Channel health status and retry handling remain unchanged.
3. Do not turn test assertions off. Tests updated to assert actual five-tab navigation, pinned player and search behavior.
4. Keep old v0.1.4+5 version and platform scripts unchanged.

## Local gates still required
`dart format lib/app/home_screen.dart test` -> `flutter analyze` -> `flutter test --reporter expanded -j 1` -> Android Mobile build/launch -> Smart TV build/remote validation -> Windows build/keyboard validation. These have NOT been run in this environment: Flutter and Dart SDK are not installed here. Do not ship as proven release before these gates pass.

## VULNERABILITY, FLAW & REAL-WORLD FIX REPORT
- **Home congestion / playback offscreen**: player aur bahut saare channel controls ek hi scroll mein hone se playback invisible tha. Fix: player ko fixed top viewport aur channel browser ko dedicated tab.
- **Keyboard-induced layout collapse**: keyboard open hone par available height chhoti pad sakti thi. Fix: focused search mode mein compact video viewport, hide non-essential filter controls temporarily, TextField mounted.
- **Potential duplicate playback session**: alag-alag screens mein naya PlayerView banane se playback restart ho sakta tha. Fix: tab changes only swap workspace below one shared PlayerView.
- **Cross-platform remote/desktop regression**: full-screen landscape/player actions must remain intact. Fix: original player branch preserved; manual TV D-pad, fullscreen, Windows sizing checks still necessary.
- **Performance with 50k+ channel catalogs**: Home par poori list build na ho. Fix: Home previews at most 3 entries, Channels retains lazy ListView.builder. Full list filtering on every rebuild is a pre-existing performance area that still needs device profiling.
