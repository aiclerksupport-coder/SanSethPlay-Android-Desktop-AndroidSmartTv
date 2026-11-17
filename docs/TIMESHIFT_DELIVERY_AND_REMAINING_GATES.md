# SanSeth Play — Live Timeshift source checkpoint

Baseline: `SanSeth-Play-v0.1.0-CAST-RECORDING-RECOVERY-INTEGRATION-SOURCE.zip`
App version unchanged: `0.1.0+1`.

## Implemented this batch
- New `HlsTimeshift` source module: local loopback HLS playlist, downloaded MPEG-TS segments in temporary app-owned disk directory, 5-minute rolling duration bound, 128 MiB maximum segment budget, no persistent archive.
- Random loopback URL segment with GET-only access. No external server binding.
- Enforces maximum 2 MiB manifest and 16 MiB segment response; rejects incompatible encrypted/fMP4 HLS using the existing strict media playlist parser.
- Initial fetch skips excessive historical segments; the refresh loop only considers recent segments.
- Eviction removes outdated segment files. Restart/Stop and channel-change clean up temporary files and shut down HTTP clients.
- Player control: **Start Timeshift** for compatible HLS, **Go Live** to re-open original source. Normal play/pause and seek are provided by `media_kit`, subject to decoder support.
- Android native runner generator now writes an explicit narrow network-security-config permitting local `127.0.0.1` HTTP for the loopback media proxy. Broad arbitrary-host cleartext is not enabled.
- Added pure manifest/unit tests plus a loopback HTTP integration test. NOT executed in this environment.

## Explicit unsupported cases
- DRM, AES-encrypted HLS, fMP4/CMAF, MPEG-DASH, RTSP, authenticated custom HTTP headers, discontinuous HLS segments and providers with unusual media URLs.
- Full universal DVR, time-shifting beyond bounded cached segments, recording from protected streams, cross-device casting of the local loopback URL.
- Non-HTTPS remote streams on Android may be restricted by network security policy. Direct user-provided HTTP streams need a separately reviewed compatibility strategy.
- Local playback duration/seek of a sliding live playlist has NOT been validated on Android or Windows media decoders. Some backends may not expose a seekable duration; do not present it as guaranteed.
- New timeshift code does not supply an offline fully playable recording: the buffer disappears on Stop, channel change, exit and cache cleanup.

## Blocking production tests — run on Windows with Flutter SDK and Android toolchain
1. `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`
2. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1`
3. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:DEBUG_PORT"`
4. `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1`
5. Manually test actual 1080p HLS source at Live / 30s delayed / Pause / Seek / Go Live on Android phone, Android TV remote and Windows; check decoder/OS localhost policy, memory, disk, TV D-pad and 2h looping.
6. Test Google Cast receiver session with a real Chromecast, HLS live playlist refresh and DVR stale segments; Windows SMTC media keys; Windows installer on clean test VM; Android 12+ splash screenshot; native sign/upgrade/uninstall.

## Safety/production notes
`HlsTimeshift` is a restricted optional implementation, **not** a verified universal DVR. Do not claim any release success without actual Flutter compilation, tests and physical hardware evidence. Do not publish unverified APKs/installer. All approved brand artwork is byte-for-byte preserved.
