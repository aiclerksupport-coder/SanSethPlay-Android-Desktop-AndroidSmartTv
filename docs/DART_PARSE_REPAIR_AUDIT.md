# SanSeth Play v0.1.0+1 — Dart parser and format repair

## Actual failure
The supplied logs show stage `04_dart_format_check` terminated before analyze/tests, with `Could not format because the source could not be parsed`. The master pipeline correctly blocked GitHub push.

## Changes
- `lib/app/xtream_browser.dart`: removed one surplus closing `)` after `Dialog.fullscreen`.
- `lib/player/player_view.dart`: removed one surplus closing `)` after `ConstrainedBox` in the settings bottom sheet.
- `scripts/RUN_PIPELINE.ps1`: format files in-place, then verify format deterministically; do not proceed to analysis if parsing fails.

## Verification
- Structured delimiter scan over all `lib/**/*.dart` files: PASS. This is not a Dart compiler.
- ZIP CRC integrity check: PASS.
- Flutter SDK / Dart SDK are not installed in this sandbox: actual `dart format`, `flutter analyze`, tests, APK/EXE builds require user Windows SDK.
- No GitHub push was performed.

## Safeguards
- Preserve the existing app version, logo, launcher artwork, Xtream/M3U/EPG/recording features and platform-specific build/install scripts.
- All downstream commands stay gated on failure.
- Flutter `doctor` can warn about missing Visual Studio C++ toolchain: Windows build/install will still require installation of the Desktop development with C++ workload.
