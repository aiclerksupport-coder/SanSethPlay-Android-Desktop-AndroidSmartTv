# SanSeth Play v0.1.0+1 - UI / UX and Live Aspect Batch

## Reference and implementation boundaries
- Reference: user-supplied StreamKey splash and icon screenshots (not screenshots of all its inside screens). Official listing consulted for typical M3U playlist discovery patterns. Layout was NOT copied.
- Original SanSeth golden S symbol and assets remain unchanged. No change to version, stream handling, URL parsing, playback retries, Xtream, cache, DVR, Cast or build/install scripts.
- New Home: simplified top actions, always-visible Playlists entry, TV guide and recordings shortcuts, immediately visible All/Favorites/Recent filters, rounded controls and more spacious focus surfaces.
- Player: one-tap live aspect cycling Fit -> Crop -> Stretch -> Original -> Fit; keyboard A on player focus. Changes `Video(fit: ...)` in the existing running player without restarting its stream. Fit preserves source, Crop can hide edges, Stretch distorts shape, Original is unscaled and may clip.
- Same shared Flutter/Dart files are used for Android Mobile, Windows Desktop and Android TV; TV D-pad hardware behavior is not certified by source tests.

## Regression and device acceptance
1. `dart format lib test` and `flutter analyze` must pass.
2. `flutter test --reporter expanded -j 1` must pass, including responsive sizes, keyboard auto-popup and new Home navigation tests.
3. Android Mobile release build/install and 10-minute playing stream test. Tap live aspect button four times; confirm no stream reload and no popup keyboard.
4. Android TV remote: focus navigation to playlists, categories and aspect control; avoid focus getting trapped.
5. Windows: keyboard A on player focus and resizing 320/360/800/1024/1920 widths; test all aspect modes, overflow, media shortcuts.
6. Check duplicated GitHub M3U URL is still rejected and saved playlists survive restart; no playlist data migration is necessary.

## Risks
- The new small-screen navigation chip row requires device-level text-scale/large-font testing to rule out clipping.
- `BoxFit.fill` stretches pixels; it's deliberate and selectable, not a streaming quality change.
- Full app UI beyond Home and Player controls was not redesigned in this bounded batch; other dialogs retain their original components and should be separately reviewed.
- Flutter SDK and hardware unavailable in this environment; tests/builds are not marked PASS.
