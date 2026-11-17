# SanSeth Play v0.1.0+1 — Targeted Pending Modules Continuation

## Source changes actually made

- Android Google Cast Sender SDK **integration source**: native route picker, active session check, load supported HTTPS public HLS/MP4/TS stream, disconnect. Setup code generates Cast options provider, Gradle dependency and manifest metadata. **Android only, requires Google Play services; casting is not receiver-tested.** Native `load` success means *request submitted*, not playback confirmed.
- Android recording free-space preflight via native `StatFs`, 256 MiB minimum at start; source still has 1 GiB/60 min caps. **Not a continuous low-storage monitor.**
- Atomic recording finalization: `.ts.part` while recording; `.ts` only after flush and packet alignment. Unexpected interruption retains `.part` for explicit manual recovery in Recordings Library. Recovery discards torn trailing packet, does not fix corrupted video codecs.
- Safety tests for Cast URL restrictions and recovered TS packets.

## What remains / cannot be signed off yet

- Google Cast receiver discovery/session/load **on real hardware** and Cast on Windows. Android Cast sender is introduced here, **not tested**.
- Full DVR timeshift: rolling segment storage, seekable live edge, segment-discontinuity handling, in-progress playlist service and multi-platform decoder compatibility are **not built**. Existing Catch-up/TS recording is not full DVR.
- Continuous Android low-storage notification / Android process-kill restoration and Windows free-space monitoring are **not complete**; interruption recovery is source added.
- Windows SMTC already existed, native splash was already added, Windows installer generator already existed; actual runtime/execution/signing checks **not done**.
- Flutter analyze, unit tests, APK, Windows EXE, physical Android Mobile/Android TV and Cast receiver tests **not done** because those toolchains/devices are not available here.

## One-line commands after extracting ZIP (VS Code PowerShell)

```powershell
.\RUN_ALL_TESTS.ps1
.\BUILD_ANDROID_MOBILE.ps1
.\BUILD_WINDOWS_INSTALLER.ps1
.\BUILD_ANDROID_TV.ps1 -DeviceSerial "TV_IP:DEBUG_PORT"
```

Do not issue the new ZIP to consumers as a production-ready app until all required tests pass. Use only lawful, authorized streams and recordings.
