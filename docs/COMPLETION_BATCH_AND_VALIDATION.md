# SanSeth Play — Pending-feature implementation checkpoint

Version: `0.1.0+1` (unchanged). Authoritative input: `SanSeth-Play-v0.1.0-CATEGORY-WISE-UNLIMITED-DEDUP-SOURCE.zip`.

## Actually implemented in this checkpoint

1. **Android native MediaSession transport bridge** generated reproducibly from `tool/native_media_activity.kt.template` by `tool/prepare_platforms.ps1`. It exposes Play, Pause, Stop, Next and Previous commands. Dart player state, programme title, and VOD duration/position are published through a MethodChannel. On Android TV and Android mobile, OS controllers can request transport actions, subject to actual Android/remote capabilities.
2. **Dual-player isolation:** secondary multiview never registers as the owner of OS MediaSession controls.
3. **Provider-advertised M3U catch-up:** `catchup`, `catchup-source`, and `catchup-days` metadata parsed, encrypted channel snapshot includes these properties, XMLTV historic items may open replay links when the template uses supported Unix-time tokens (`{utc}`, `{utcend}`, `{start}`, `{timestamp}`, `{end}`, `{duration}`, `{Y}`, `{m}`, `{d}`, `{H}`, `{M}`, `{S}`). This is **not** local recording or universal DVR; source server must provide the archive.
4. **Windows installer legal publisher identity:** set `AppPublisher` to the individual developer instead of implying that Sanwariya is an already registered legal company.
5. **Regression test sources** written for valid historic programmes, metadata cache roundtrip, unsupported feed and expired/future programmes.

## Not implemented / do not mark passed

- Universal DVR recording or pause-live with local timeshift buffer; most remote streams do not authorize it and require disk quota, rights and segment persistence design.
- Google Cast/Chromecast sender (requires authenticated receiver discovery, native Cast SDK setup and casting-compatible media URLs); no fake Cast button added.
- Windows native media control/session integration beyond existing player/keyboard controls.
- Final Android 12+ native full-portrait splash sign-off: Android OS owns the system splash; the full artwork can be presented inside Flutter immediately after startup.
- Physical Android mobile/TV playback/remote, Windows clean-install, long-running stream, codec and device performance validation. No Flutter/Dart SDK or devices available in this execution environment.

## Commands — use in VS Code PowerShell on Windows

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:PORT"
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_WINDOWS_INSTALLER.ps1
```

Use one command at a time. Flutter Android/Windows targets must be installed; Android TV must be an authorized ADB device. Tests, builds, and install are **not** claimed passed in this source checkpoint. Scripts provide verbose terminal output and failure-only log files.

## Required physical acceptance before production

- Android phone API 26+, recent Android releases, multiple OEM devices: OS Play/Pause/Next/Previous buttons, PiP, process foreground/background, headset key, orientation lock.
- Android TV: D-pad navigation, media keys, track selection, initial launch icon/banner, 2-stream decoder memory test, 8-hour playback with network interruptions.
- Windows: clean VM setup install/uninstall/upgrade, codecs, DPI 100/150/200%, 1024×768 and large screens, GPU fallback, audio output, task-switching.
- M3U: 1/100/1000 saved sources, GitHub raw/blob canonical duplicates, category counts, reload after restart, offline caches, catch-up template correctness on a provider that explicitly advertises archive.
- Security: playlist URLs/credentials excluded from logs, invalid URL redirects, database corruption and key recovery, provider archive expiry and rate limits.

## Risks to resolve in next production gate

- Native MediaSession callback may behave differently between OEM TVs and media remotes; tests must prove external key events route to the visible primary pane and background playback policy is honored.
- Catch-up URL template protocols vary by vendor (e.g. URL-encoded dates or other placeholders). Unsupported formats are disabled, not guessed; test against providers' published formats.
- No actual Dart analyze/format/test invocation was run in this environment. Run the four commands above and inspect failure logs before any public release.
