# SanSeth Play: Android auto-install wrapper fix (v0.1.0+1)

## Root cause
The three platform wrappers forwarded an empty `-DeviceSerial` value to `powershell.exe -File`, causing `Missing an argument for parameter DeviceSerial` before Flutter started. Empty `TvHost` and false switches had the same invocation ambiguity.

## Fix
Parameter arrays now contain only non-empty serial/host fields and enabled switches. With a single authorized Android phone, use `powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1` without any serial. With multiple devices, `-DeviceSerial` is still supported.

## Separate analyzer blocker
The user's earlier analyzer reported 68 issues. The provided `FAILED_pipeline-v0.1.0_1(1).log` gives a total only and not the individual diagnostics. The correct full details are in the `failure-logs/FAILED_05_flutter_analyze-v0.1.0_1.log` file (if produced by Invoke-Checked).

To collect everything in VS Code PowerShell:

```powershell
flutter analyze --no-pub 2>&1 | Tee-Object -FilePath .\failure-logs\ANALYZE_FULL-v0.1.0+1.log
```

Do not push to GitHub until analyzer/tests/builds pass. This repair is for CLI argument forwarding only and is not a claim of resolved analyzer issues.
