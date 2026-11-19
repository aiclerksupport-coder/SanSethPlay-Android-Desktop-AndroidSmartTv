# SanSeth Play v0.1.4+5 — Premium Home/UI release notes

Approved visual reference: user's navy/gold full-screen OTT home mockup.

## Implemented
- Updated Material 3 global colors, navigation bar, chips, inputs and card treatments across mobile, Android TV and Windows.
- Mobile portrait Home changed to a scrollable dashboard, protecting content from clipping behind bottom navigation.
- Channel browser gets left-side vertical actions for Playlists, Categories, All, Favorites, Recent, EPG and Recordings.
- Search remains mounted during keyboard resize, and channel rows remain lazily built with ListView.builder for large M3U catalogs.
- Active playlist label, channel count, current stream and category are kept distinct.
- Playback/stream parsing, credentials, repositories, EPG loading, DVR and permissions were intentionally not modified.

## Important limitations
The illustrative mockup contains a fictional/visual video still and a progress indicator; the live app uses real video/metadata and will not reproduce these as fake content. Exact pixel identity depends on device size, font scale and provider data. Screen-wide scrolling is essential on shorter phones, so all channel rows are reachable by scrolling instead of falsely showing all 50,000 at once.

## Validation on user's Windows Flutter machine
```powershell
flutter analyze
flutter test --reporter expanded -j 1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1
```

No Flutter executable was available in this authoring environment. Tests were added but not run here; do not treat source-only checks as proof of zero analyzer warnings or zero widget failures.
