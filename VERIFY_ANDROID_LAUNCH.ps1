# Post-install cold launch check, compatible with Windows PowerShell 5.1.
[CmdletBinding()]
param([string]$DeviceSerial = '', [string]$PackageId = 'com.example.sanseth_play', [switch]$Tv)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$logDir = Join-Path $Root 'failure-logs'
$transcript = New-Object 'System.Collections.Generic.List[string]'
function Run-Adb([string[]]$Arguments) {
  $commandText = 'adb ' + ($Arguments -join ' ')
  Write-Host "> $commandText" -ForegroundColor Cyan
  $script:transcript.Add("> $commandText")
  # Windows PowerShell 5.1 can promote native stderr to terminating errors
  # when ErrorActionPreference=Stop. Capture output regardless of exit status.
  $prior = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $lines = @(& adb @Arguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prior
  }
  foreach ($line in $lines) {
    Write-Host $line
    $script:transcript.Add([string]$line)
  }
  if ($exitCode -ne 0) { throw "ADB exited ${exitCode}: $commandText" }
  return $lines
}
try {
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { throw 'adb not found' }
  $all = @(Run-Adb @('devices'))
  $serials = @($all | Where-Object { $_ -match '^([^\s]+)\s+device\b' } | ForEach-Object { ($_ -split '\s+')[0] })
  if (-not $DeviceSerial) {
    if ($serials.Count -ne 1) { throw "Expected one ADB device, found $($serials.Count); supply -DeviceSerial" }
    $DeviceSerial = $serials[0]
  }
  if ($serials -notcontains $DeviceSerial) { throw 'Selected device is not connected and authorized' }
  $packages = (Run-Adb @('-s',$DeviceSerial,'shell','pm','list','packages',$PackageId)) -join "`n"
  if ($packages -notmatch [regex]::Escape("package:$PackageId")) { throw 'SanSeth Play package not installed' }
  # Explicit component avoids monkey's noisy stderr and launcher-selector
  # variability. Same MainActivity declares mobile and Leanback intent filters.
  $activity = "$PackageId/$PackageId.MainActivity"
  $category = if ($Tv) { 'android.intent.category.LEANBACK_LAUNCHER' } else { 'android.intent.category.LAUNCHER' }
  [void](Run-Adb @('-s',$DeviceSerial,'shell','am','force-stop',$PackageId))
  $launch = (Run-Adb @('-s',$DeviceSerial,'shell','am','start','-W','-a','android.intent.action.MAIN','-c',$category,'-n',$activity)) -join "`n"
  if ($launch -match '(?i)error:|exception|does not exist|permission denial|unable to resolve') { throw 'Android Activity start was rejected' }
  Start-Sleep -Seconds 4
  $pidResult = (Run-Adb @('-s',$DeviceSerial,'shell','pidof',$PackageId)) -join ''
  if ($pidResult -notmatch '\d+') { throw 'App process not alive four seconds after launch' }
  Write-Host "PASS: $PackageId cold launched and process alive on $DeviceSerial" -ForegroundColor Green
  Write-Host 'This smoke test does not certify playback, casting, DVR or UI performance.' -ForegroundColor Yellow
} catch {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  $file = Join-Path $logDir 'FAILED_ANDROID_LAUNCH-v0.1.1+2.log'
  $transcript.Add("Failure: $($_.Exception.Message)")
  $transcript.Add("Device: $DeviceSerial")
  $transcript.Add("Package: $PackageId")
  $transcript | Set-Content -Path $file -Encoding UTF8
  Write-Host "FAILED: $($_.Exception.Message). Full log: $file" -ForegroundColor Red
  exit 1
}
