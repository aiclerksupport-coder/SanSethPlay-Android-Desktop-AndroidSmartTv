# SanSeth Play engineering acceptance roadmap

## P0 — platform gates
1. Generate native wrappers using `flutter create` and lock a Flutter/Dart SDK version.
2. Fix any analyzer/build issues discovered on your toolchain; run Flutter test suite at 320x640, 360x800, 768x1024, 1280x720, 1920x1080, 3840x2160, 200% accessibility text and keyboard accessibility.
3. Install real icon and native launch assets in Android/iOS/macOS/Windows/Linux. Android 12 splash icon specifics and Android TV landscape splash must be handled using platform-native templates.
4. Android TV remote: D-pad navigation, focus ring, Back semantics, leanback launcher intent, remote seek/volume, 10-ft typography.
5. Test cold start, rapid stream switching, orientation changes, resume/background, bad links and weak network.

## P1 — end-user player
1. Durable encrypted local playlist store with safe backups and migrations.
2. HLS playback matrix, DASH/MP4 as supported, advanced controls, subtitles/audio track, buffering UX, retry backoff.
3. EPG XMLTV download/parse with background isolate, timezone handling and cache.
4. Favorites, recent channels, groups, full search; optional user-supplied Xtream API accounts, without storing raw credentials in logs.
5. Source-type-specific DRM and license compliance review before production.

## P2 — quality and security
- Isolate playlist parsing, images cache bounded by memory budget, virtualized lists, lazy loading, no massive synchronous deserialization.
- Debounce rapid buttons and cancel stale asynchronous requests with generation IDs.
- Network controls: SSRF/localhost/IP protections if playlists are ever fetched through cloud services; on-device policy and redirect rules.
- Validate stream permissions, audit native licenses and platform store policies.
- Release profile benchmark CPU/GPU memory, p95 frame times and startup, repeat per platform.
