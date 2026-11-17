# SanSeth Play — Real Open-Source IPTV Feature-Gap Review

Basis: 2026-11-17 source inspection of the existing SanSeth Play v0.1.0+1 three-platform pipeline archive and public project documentation. Do not confuse documented upstream features with features verified in SanSeth Play.

## Source references (independent projects; no source-code copying)

- IPTVnator: https://github.com/4gray/iptvnator — multi-source playlists (M3U/Xtream/Stalker), resume/recent, EPG, VOD, catch-up and desktop workflow.
- OpenTV: https://github.com/opentvproject/opentv — Android TV remote-focused design, EPG and provider-dependent catch-up.
- OpenIPTV: https://github.com/DR-89/openiptv — Flutter player ecosystem; M3U/Xtream and cross-platform capabilities.
- iptv-org: https://github.com/iptv-org/iptv — M3U source format and playlists, not an assurance that streams are available or licensed for redistribution.
- media_kit: https://github.com/media-kit/media-kit — Flutter native media playback capabilities.

## Verified from local source

Existing: URL M3U import, GitHub blob normalization, local encrypted playlist metadata, SQLite channel snapshot, XMLTV cache and guide, play/pause, track selection, captions, volume, TV keyboard controls, PiP entry point, device-build pipeline. These were code-inspected, not device-tested.

## Implemented in this batch

1. Recently Watched: up to 40 channel identifiers, most-recent-first, local persistent list and clear control. No raw URLs/tokens saved in history. Works across sources as long as the same stream URL is present.
2. M3U parsing: handles UTF-8 BOM, CR-only legacy line endings, and blank EXTINF display names via `tvg-name` fallback. Preserves existing URL scheme filtering and channel cap.
3. Rapid remote navigation: removes the UI-level selection throttle which discarded a last keypress; PlayerView's existing latest-request-wins open queue handles decoder starts.
4. Regression tests for bounded/redacted history and legacy M3U variants. Tests **not run** in the tool environment.

## Feature-gap matrix

| Capability | Status |
|---|---|
| Recent watching and clear history | Implemented source, uncompiled |
| Public M3U / M3U8 and GitHub source | Existing source, unverified |
| Local channel cache / XMLTV guide | Existing source, unverified |
| Multi-playlist / favorites | Existing source, unverified |
| Playlist import via local file picker | Not implemented |
| Xtream Codes account, category/catalog API | Not implemented |
| Stalker portal | Not implemented; security/legal protocol assessment required |
| VOD, movies, seasons/episodes, watch-resume | Not implemented |
| Provider-backed catch-up/DVR/time-shift | Not implemented |
| Authenticated HTTP headers/user agents per playlist | Not implemented |
| Streaming diagnostics, bitrate, codec matrix | Not implemented |
| Full multiview, cast/Chromecast | Not implemented |
| Native Android media session/background audio | Not implemented |
| End-to-end device-build/test on 3 platforms | Not verified |

## Production gates

1. Run `RUN_ALL_TESTS.ps1` and each platform's build/install script on Windows with Flutter/Android/Visual Studio; attach failure logs only after redacting tokens.
2. Verify Android TV hardware D-pad Back/OK/media keys; ensure every focusable control is visible.
3. Validate protected stream headers, DRM/codec restrictions, memory under 20k channels, stream reconnection and URL redirects before shipping.
4. Check licensed/authorized playlist sources only; this application does not ship channels or subscriptions.
5. Track build output, APK package identity, signing and Windows install/uninstall smoke tests.
