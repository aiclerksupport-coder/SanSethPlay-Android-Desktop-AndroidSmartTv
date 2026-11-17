# Analyzer issues: evidence and next gate

The uploaded `FAILED_pipeline-v0.1.0_1(2).log` reports **68 issues found** at `05_flutter_analyze`, but contains no per-diagnostic error messages, filenames, line numbers or analyzer codes. Therefore no trustworthy classification, exact repair, or PASS claim can be made from that file alone.

## On the user's Windows PC

Run once from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ANALYZE_DIAGNOSTICS.ps1
```

If it fails, share `failure-logs/ANALYZE_FULL-v0.1.0+1.log` and `failure-logs/ANALYZE_MACHINE-v0.1.0+1.log`. These provide the actual error codes and locations; the prior pipeline's top-level FAILED log does not. Do not downgrade analyzer severity or use `--no-fatal-warnings` as a substitute for fixing issues.

This diagnostic checkpoint is **not** a repair of the 68 unresolved findings. The sources and GitHub push gate are kept intact.
