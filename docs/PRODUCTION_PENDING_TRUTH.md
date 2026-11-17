# SanSeth Play — Advanced batch implementation and remaining gates

## Implemented in this source batch
- VOD and series playback positions in bounded local preferences, keyed by SHA-256 rather than credential-bearing URLs. Applies to explicit on-demand Xtream media only; does not pretend that live HLS streams support resume. Clears played-to-95%-completion position.
- Two-channel multiview (two actual media_kit decoders, secondary muted by default), selected from current imported M3U playlist. In a low-memory TV this can still fail to allocate the second decoder. No promise of four independent streams or synchronized audio.
- Windows Inno Setup 6 installer one-liner after existing Flutter build/analyze/tests. All release DLL/data files included. Installer is *not signed*.

## Not completed / cannot certify here
- DVR/catch-up: provider-specific URL templates, EPG archive metadata and time-shift seek window must be tested with authorized actual providers; none provided. Do not offer fabricated seekable DVR controls.
- Chromecast/Cast: a native receiver protocol/session/discovery implementation and physical Chromecast/Google TV testing are missing. Plain casting to a URL might expose authentication credentials and is not safe.
- Native Android MediaSession with correct audio focus, transport synchronization, TV remote callbacks and Android background lifecycle is not completed. Existing Flutter remote commands remain in-app.
- Native splash on Android 12+ cannot show the complete 9:16 lockup as an OS splash. Flutter-branded first screen is needed to match the artwork; Windows start screen likewise is not a native system splash.
- Real APK, Windows installer, Android TV D-pad, 1080p/4K codec decoding, hardware benchmarks and physical installation **cannot be verified without Windows Flutter SDK, Visual Studio, connected phone and TV**.
- 2-decoder multiview needs OOM and rapid-select tests on low-RAM devices; second stream is muted, so user can focus primary audio.
- Windows installer needs a publisher signing certificate for public distribution; current setup may trigger Windows warnings.

## One-line commands in VS Code PowerShell
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:PORT"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`
- `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`

These commands are Windows-native. Terminal output is verbose; on failure, logs are saved inside failure-logs. Tests are not claimed passed until run on a real configured Windows machine.
