# SanSeth Play - one-line build/test/install; automatic device selection.
# Windows PowerShell 5.1 compatible. Pass only explicitly provided parameters.
[CmdletBinding()]
param(
  [string]$DeviceSerial = '',
  [string]$TvHost = '',
  [switch]$SkipInstall,
  [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
$syntaxCheck = Join-Path $PSScriptRoot 'scripts/VERIFY_POWERSHELL_SYNTAX.ps1'
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $syntaxCheck
if ($LASTEXITCODE -ne 0) { exit 1 }

$pipeline = Join-Path $PSScriptRoot 'scripts/RUN_PIPELINE.ps1'
$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $pipeline, '-Target', 'android-tv')
if (-not [string]::IsNullOrWhiteSpace($DeviceSerial)) {
  $arguments += @('-DeviceSerial', $DeviceSerial)
}
if (-not [string]::IsNullOrWhiteSpace($TvHost)) {
  $arguments += @('-TvHost', $TvHost)
}
if ($SkipInstall.IsPresent) { $arguments += '-SkipInstall' }
if ($SkipTests.IsPresent) { $arguments += '-SkipTests' }
& powershell.exe @arguments
$code = $LASTEXITCODE
if ($null -eq $code) { $code = 1 }
exit [int]$code
