# SanSeth Play v0.1.0+1 - Windows / Landscape Controls Patch

Base: SanSeth-Play-v0.1.0-POWERSHELL-LAUNCH-PARSER-FIX-SOURCE.zip

## Observed Windows failure
The supplied 2026-11-18 log explicitly reports `Unable to find suitable Visual Studio toolchain` and Flutter Doctor reports missing Visual Studio Desktop development with C++. Install Visual Studio with MSVC x64/x86, CMake and Windows SDK. This is a machine prerequisite, not a Dart source compile error. Official: https://docs.flutter.dev/platform-integration/windows/setup

## Source modifications
- Android player uses one overlay control layer rather than simultaneously exposing native/adaptive video buttons and custom overlay buttons.
- On Android, Previous / Play or Pause / Next are centered. Fullscreen and Settings occupy top right. Aspect ratio cycles bottom right without overlap.
- On Android phone landscape, player controls and Home landscape shortcuts auto-hide after 2 seconds. Touching video reveals them and restarts timer.
- Manual Android fullscreen sets landscape orientation; returning uses platform orientation settings and parent layout fallback.
- Compact mini-player avoids full controls. Windows keeps its native adaptive controls and native fullscreen/seek behavior. Android TV maintains non-editable D-pad focus.
- Windows build and installer use a preflight toolchain checker for quick actionable diagnostics.

## Test status
Static source checks and ZIP integrity executed. Flutter/Dart SDK, Windows native MSVC and connected hardware are unavailable in this execution environment. `flutter analyze`, Flutter tests, Windows EXE, APK builds and physical rotation tests are NOT certified by this archive. Previous user-confirmed Android APK build/install/launch applies ONLY to the original base ZIP.

## Local verification
Run `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1` then test portrait fullscreen, rotate, 2-second hide and tap-to-reveal.
After installing Visual Studio C++ workload, run `flutter doctor -v` and `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`.

## Change list
- BUILD_WINDOWS_INSTALLER.ps1
- lib/app/home_screen.dart
- lib/player/player_view.dart
- scripts/RUN_PIPELINE.ps1
