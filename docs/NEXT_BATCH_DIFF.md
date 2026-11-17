# SanSeth Play — EPG Timeline & Auto-Refresh Batch

- Retains `0.1.0+1` version, all original approved branding files unchanged.
- Adds a horizontally aligned six-hour XMLTV timeline with 30-minute ticks, lazy vertical channel rows, scrollable on small screens and navigable with desktop/TV focus controls.
- Adds saved XMLTV URL in platform secure storage and periodic *foreground-only* refresh every 90 minutes. Failed refresh preserves in-memory guide; guide programmes are not persisted offline.
- Adds pure timeline clipping tests for overlapping and off-window programmes.

## Remaining production gates
- Flutter SDK not available in authoring environment: `flutter pub get`, `flutter analyze`, `flutter test`, APK/Windows release builds are NOT verified.
- EPG limit remains 4 MB and 12,000 programmes. Compressed XMLTV feeds, persistent programme database, large-feed streaming parsing, PiP, multiview, codec-by-codec device verification, native splash and Windows installer remain pending.
- Android TV physical remote, 320px mobile, Windows DPI scaling, Android 12+ splash and real network trials are required.
- Only use rights-cleared playlists/streams.
