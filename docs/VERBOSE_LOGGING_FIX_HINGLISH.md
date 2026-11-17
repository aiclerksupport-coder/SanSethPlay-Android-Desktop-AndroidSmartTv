# Verbose terminal aur failure logs - v0.1.0+1

- Har native stage ke output ko terminal par real time print kiya jata hai aur `failure-logs/RUNNING_*.tmp.log` mein AutoFlush ke saath likha jata hai.
- PASS par temporary file delete hoti hai, FAIL par `FAILED_<stage>-v0.1.0_1.log` ke roop mein complete transcript rehti hai.
- `RUN_ANALYZE_DIAGNOSTICS.ps1` failure par `ANALYZE_FULL-v0.1.0+1.log` aur `ANALYZE_MACHINE-v0.1.0+1.log` banata hai.
- Windows PowerShell 5.1 mein stderr ko terminating error banne se bachane ke liye native invocation ke dauran scoped `ErrorActionPreference=Continue` use hua hai. Nonzero exit code ab bhi failure hai.
- Command: `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ANALYZE_DIAGNOSTICS.ps1`
- Full pipeline: `powershell -NoProfile -ExecutionPolicy Bypass -File .\RUN_ALL_TESTS.ps1`
- Build ke baad hi optional Android device auto detection hogi.
- Kisi bhi fail stage ka log user se mangkar exact Dart/Kotlin/Gradle issue fix karein; analyzer failure ko fake PASS mat banayein.
