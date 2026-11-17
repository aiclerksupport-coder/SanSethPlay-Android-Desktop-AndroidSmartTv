# SanSeth Play — Offline/EPG/TV Batch (v0.1.0+1)

## Implemented in source (not compiled in this environment)
- Per-playlist encrypted last-known-good channel cache, capped at 1500 channels / 350 KiB per playlist. Cache shown before network refresh; errors/empty remote data never delete good cache. Fails gracefully when too large or secure store unavailable.
- XMLTV EPG URL manual import; 4 MiB max, 12000 parsed programme cap, `compute()` parsing, live NOW labels matched to `tvg-id`. XMLTV is session-only and URL not persisted.
- Remote keyboard/TV focus ring and Enter/Select channel activation; narrow AppBar overflow mitigation by moving actions to a menu.
- Regression tests for safe cache decode and XMLTV timezone / invalid records.

## Not falsely marked complete
- Full cached 20K-channel DB: not provided; encrypted secure store has deliberate size limits. SQLite/SQLCipher or disk AES-GCM cache is needed for large source listings.
- EPG refresh schedule, EPG zipped XMLTV feeds, EPG mapping for sources without `tvg-id`, 7-day grid and catch-up: not implemented.
- Physical Android TV remote / Android 12 splash / native Windows packaging and cold-start speed: not verified.
- Credential-safe cross-device sync, DRM, PiP, codec matrix, multiview, Xtream authentication, robust reconnection and player fallback: not implemented.
- No original logo file was changed, and original player behavior is preserved.

## Release acceptance
1. Run `BUILD_ALL.ps1` on Windows with Flutter, Android SDK and Visual Studio C++ tools.
2. Test 320x568, 360x640, 800x480 landscape, 1920x1080 Android TV with hardware D-pad, plus 125%/200% Windows display scaling.
3. Test saved source after 10+ offline days; stale cache must show, even if link cannot refresh. Test full 20k channel input (expect noncached source) and interrupt secure storage writes.
4. Inspect real native splash (Android 12+ imposes OS constraints), screen reader, Back behavior, streaming formats and source redirects.
5. Validate no logged credential URL or token, no insecure/private-network URL fetching on untrusted devices; add private-host/redirect hardening before general release.

## Security note
Encrypted secure storage is OS-managed and not guaranteed to survive uninstall/reinstall or system key reset. Cache is a convenience, not a backup. Never log user-provided stream URLs. Streams themselves still require connectivity.
