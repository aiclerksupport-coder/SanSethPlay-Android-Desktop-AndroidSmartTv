# SanSeth Play v0.1.1+2 — Change 1–5 implementation & verification report

**Base:** `SanSeth-Play-v0.1.0+1-PREMIUM-PLAYER-LANDSCAPE-OVERFLOW-TEST-FIX-SOURCE.zip` (user-confirmed Android Mobile release build/install/cold launch successful). Base files were not removed.

**Change 1 — Player controls + recording**
- Unstructured button `Wrap` replaced by section-based 2-column controls, Fit/Crop/Stretch/Original choices, volume/speed/rotation, captions and live tools. Enabled actions remain wired to existing player calls.
- Recording sheet now shows what is **really supported**: original channel audio + video from direct TS or TS-segment HLS recorded as MPEG-TS `.ts` in app documents, with existing export flow.
- **Not delivered:** microphone/outer-voice, mixed system+microphone recording, MP4/H.264 transcoding, custom quality or alternate save directories. These require platform-specific capture/mixing, user microphone/MediaProjection permissions (where applicable), encoders, audio focus and synchronization. UI clearly marks the unavailable modes disabled. No fake success claim.
- Some third-party/live formats, DRM and native cast receiver combinations are unsupported by design. Source stream may not permit recording.

**Change 2 — Top bar menu**
- Enlarged popup with Gold/Navy border, icons, section headings Playlist & Content / Help & Info / Tools, and a conspicuous red remove action. Existing click handlers retained.
- Narrow-screen popup has max-height bound and scrolls rather than requiring all rows at once.

**Change 3 — Mini player restore navigation**
- Restore/maximize from mini-player atomically selects Home tab (`_navIndex=0`) and ends mini mode; minimize selects Channels tab. Player widget key and media source preserved.

**Change 4 — Dialog consistency**
- App-wide dialog widths/margins, rounded borders, gold outline, input fields, bottom sheets and cards improved through Flutter ThemeData. Saved playlist dialog rows are larger and list remains scrollable. On a 320px phone, dialog content clamps to fit.

**Change 5 — Glossy accents**
- Navy/Gold palette preserved. Subtle card elevation/blue edge shadows, gold outlines and contrast enhanced. No heavy blur/video shader or expensive animation introduced.

## VERIFICATION GATES
1. On Windows with Flutter 3.44.9: `flutter pub get`, `dart format lib test`, `flutter analyze`, `flutter test --reporter expanded -j 1`.
2. Mobile: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`.
3. Android TV: `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1`.
4. Windows: requires Visual Studio Desktop development with C++ then `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`.
5. On real phone/TV: 320px / 360px portrait, 800x360 landscape, TV D-pad, quick repeated channel changes, dialog keyboard safe-area, recording start/stop/partial files, resume, cast and PiP.

**Status:** Source candidate only. ZIP/byte-level base comparison and static structure checks can be performed here; local Flutter analyzer/tests, Android/Windows builds and physical-device regression are NOT run in this environment. Do not push as production-release verified before those gates pass.

## VULNERABILITY, FLAW & REAL-WORLD FIX REPORT

- **False recording modes:** Existing Dart stream recorder cannot capture device microphone or remux to MP4. Enabling those controls would misrepresent output. Fix: production MediaProjection/microphone audio capture, explicit permissions, synchronized audio mixer, AAC encoder and MP4 muxer, plus tests on each platform. Keep disabled until implemented.
- **Unsupported source recording:** Some sources are encrypted, adaptive or not MPEG-TS. Fix: source capability detection, explicit disabled states, recoverable `.part` output, quota/error handling; never report recording success without nonempty finalized file.
- **App lifecycle:** Android process termination and focus policies can interrupt long recording/PiP. Fix: platform-compliant foreground media playback/recording service when required, lifecycle tests and clear user controls.
- **Navigation selected-state mismatch:** Old mini restore toggled only `_miniPlayer`. Fix: update `_navIndex=0` in same setState; test maximize/minimize rapid taps and back button.
- **Tiny dialogs and list overflow:** Prior popup was narrow and ungrouped, making actions hard to discover. Fix: global ThemeData and bounded scrollable dialog content, keyboard/viewport layout tests.
- **Glossy rendering performance:** Excessive BackdropFilter / shadows can cause TV jank. Fix: lightweight static borders and minimal elevation, test frame timing on real hardware.
