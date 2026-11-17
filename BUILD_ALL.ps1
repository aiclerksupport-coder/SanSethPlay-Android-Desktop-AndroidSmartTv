# Run from project root: .\BUILD_ALL.ps1
param([string]$DeviceSerial = '', [string]$TvHost = '', [switch]$SkipInstall, [switch]$SkipTests)
# Validate PowerShell syntax before calling the shared pipeline.
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'scripts/VERIFY_POWERSHELL_SYNTAX.ps1')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& (Join-Path $PSScriptRoot 'scripts/RUN_PIPELINE.ps1') -Target 'all' -DeviceSerial $DeviceSerial -TvHost $TvHost -SkipInstall:$SkipInstall -SkipTests:$SkipTests
exit $LASTEXITCODE
