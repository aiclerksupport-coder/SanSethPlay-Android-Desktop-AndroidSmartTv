# SanSeth Play — Direct TS Recording + Brand Launch Development Checkpoint

## Implemented
- Direct HTTP(S) `.ts` continuous stream recording to app documents with explicit Record/Stop control, redirect rejection, credential-in-URL rejection, 12/20 second connection/response timeouts, bounded 60-minute capture, max 1 GiB data and partial file cleanup on failure.
- Recording stops on player disposal or channel change. No recording credentials or source URLs are logged.
- Original approved portrait/landscape artwork is presented with `BoxFit.contain` for a brief transition after the OS-native splash on Android, Windows and Android TV. Brand assets are unchanged.
- New URL policy and widget smoke tests written but not run (Flutter SDK missing in this environment).

## Capability limits — do not advertise otherwise
- Recording is limited to directly accessible continuous MPEG-TS URLs ending in `.ts`. HLS `.m3u8`, DASH `.mpd`, DRM, Xtream/HLS recording and rolling timeshift are NOT implemented.
- Some `.ts` endpoints return an HTML error or require unsupported headers; a successful HTTP 200 is not proof of playable/valid MPEG transport data. Device-level recordings must be validated with a demuxer.
- The output is inside the application documents directory, **not** public TV/Downloads. Android file sharing/export is not yet implemented. Uninstall may delete recordings.
- Cast/Chromecast discovery and remote session remains pending: needs full Cast sender SDK integration and receiver test devices. Windows OS media transport integration also pending.
- Android 12+ platform splash is icon constrained; the full-lockup brand screen is an app-level transition, not replacement for OS splash. Startup time is deliberately 650 ms longer than direct HomeScreen; needs device evaluation.
- Prior native MediaSession and catch-up modules are source code only; all Flutter tests, release APK, TV APK, Windows EXE, installer and performance testing remain unverified here.

## Next production gates
1. Flutter analyze + tests; compile all target runners using the existing one-line scripts.
2. Verify media recording integrity/size/cancellation on Android phone, Android TV and Windows, including disk-full and reconnect.
3. Implement Google Cast Android sender integration with authenticated-stream privacy and receiver compatibility; not guaranteed on Windows.
4. HLS DVR archival requires permitted segment ingestion, key rotation handling, retention and seek/record UI, not raw HTTP dumping.
5. Physical TV D-pad/focus, Windows installer, Android package ID, codec and 10+ hour performance tests.
