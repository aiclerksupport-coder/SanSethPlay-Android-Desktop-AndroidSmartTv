# SanSeth Play — Release Reliability Patch

Base: `SanSeth-Play-v0.1.0-RELEASE-GATE-DVR-CAST-SAFETY-SOURCE.zip`

## Actual source changes
- Live HLS recording ab initial snapshot par sirf recent 3 segments leta hai; later polls recent 12 segments examine karte hain, aur old seen identifiers prune hote hain. Long-lived recording mein bounded memory.
- Recording recovery ab poori recoverable TS file ko 1024-packet chunks mein validate karti hai; 4096 packets ke baad corruption ignore nahi hoti. File ko validation se pehle truncate nahi kiya jata.
- Timeshift segment write complete hote waqt Stop ho chuka ho to stale segment playlist mein add nahi hota.
- Android Mobile / Android TV install ke baad automatic smoke-launch; Android TV par Leanback launcher category.
- Windows release build ke baad packaged executable launch smoke test.
- Late-corruption regression test added (written, **not run**).

## Platform verification gates — NOT PASSED
Flutter/Dart executable, Android SDK/ADB devices, Windows toolchain/Inno Setup and physical Chromecast not available in this runtime. Source comparison/ZIP checks do NOT establish compilation or runtime correctness.

## Essential real-device acceptance
1. `flutter analyze`, `flutter test`, release APK and Windows installer build pass.
2. Phone and Android TV launch from actual launcher, TV D-pad and media keys respond.
3. Test HLS timeshift pause/seek/Go Live, 2-hour playback and channel switching.
4. Force low-storage recording and abrupt process termination; recover .part file safely.
5. Cast on a real receiver, observe cast session and receiver playback; test disconnect.
6. Windows setup install/uninstall and native transport keys.
7. Screenshot layout tests for 320px mobile, resizing Windows, TV 720p/1080p and long text.
8. Run with test URLs that contain dummy credentials and confirm no logging/secrets leakage.

## Compatibility limits
No promise of universal DVR on DRM/unsupported HLS/DASH, Windows Cast sender or unrestricted hardware decoding. Full device certification is unavailable in this environment.
