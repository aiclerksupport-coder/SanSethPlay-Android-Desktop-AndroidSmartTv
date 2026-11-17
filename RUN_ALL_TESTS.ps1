# One-line tests. Fail closed if any pipeline stage fails.
$ErrorActionPreference = 'Stop'
# Validate PowerShell syntax before calling the shared pipeline.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'scripts/VERIFY_POWERSHELL_SYNTAX.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'scripts/RUN_PIPELINE.ps1') -Target tests
exit $LASTEXITCODE
