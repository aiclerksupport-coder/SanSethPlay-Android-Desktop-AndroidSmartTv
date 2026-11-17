# SanSeth Play v0.1.0+1 - Windows PowerShell Parser Repair

## Exact error
`RUN_PIPELINE.ps1:117 - Missing closing }` before executing Flutter.

## Root cause
The extracted source *did* contain the closing brace at line 133. The script was UTF-8 without a BOM and used a Unicode em dash in string literals/comments. Windows PowerShell 5.1 can decode this as the Windows system codepage and misparse the text, resulting in a misleading `MissingEndCurlyBrace`.

## Changes
- `RUN_PIPELINE.ps1`: removed em dashes and saved as UTF-8 with BOM. No Dart/business logic changed.
- All `*.ps1` scripts now use UTF-8 with BOM for Windows PowerShell 5.1 compatibility.
- Added `scripts/VERIFY_POWERSHELL_SYNTAX.ps1` which uses the built-in PowerShell AST parser to check all project scripts.
- Integrated the parser gate before tests in the master script and standalone build/test wrappers.
- Any parser error stops the command before a build or push.

## Commands
Run this first in a fresh extracted folder:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\VERIFY_POWERSHELL_SYNTAX.ps1
```

Then, with your authorized USB phone connected (auto-select, no serial needed):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_ANDROID_MOBILE.ps1
```

Complete pipeline (Android TV must also be connected for all-platform GitHub push):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\BUILD_TEST_INSTALL_GITHUB.ps1
```

## Verification limits
This environment has no `powershell.exe`, Flutter SDK or real devices, so the PowerShell parser and release builds were NOT executed here. Archive integrity, file difference and UTF-8 BOM checks were verified. User should report any new build log; do not interpret the prior parser failure as a Flutter compile error.
