# Full build -> post-build optional installs -> GitHub push only after verified installs.
[CmdletBinding()]
param([string]$MobileSerial = '', [string]$TvSerial = '', [switch]$NoPush)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
$failureDir = Join-Path $Root 'failure-logs'
$dist = Join-Path $Root 'dist'
$script:stage = 'startup'
function Step([string]$Name,[string]$Script,[string[]]$ArgsList) {
  $script:stage = $Name
  Write-Host "`n===== $Name =====" -ForegroundColor Cyan
  Write-Host "> powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script $($ArgsList -join ' ')"
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Script @ArgsList
  if ($LASTEXITCODE -ne 0) { throw "$Name failed with exit code $LASTEXITCODE" }
}
function CheckReceipt([string]$Target) {
  $receipt = Join-Path $dist "install-ok-$Target.json"
  if (-not (Test-Path $receipt)) { return $false }
  $apk = Join-Path $Root 'build/app/outputs/flutter-apk/app-release.apk'
  if (-not (Test-Path $apk)) { return $false }
  try {
    $data = Get-Content -Raw $receipt | ConvertFrom-Json
    return (($data.target -eq $Target) -and ($data.apkSha256 -eq (Get-FileHash $apk -Algorithm SHA256).Hash))
  } catch { return $false }
}
try {
  # No adb check or device enumeration at startup. Build remains possible offline.
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter SDK missing.' }
  Step '0-PowerShellSyntaxCheck' (Join-Path $Root 'scripts/VERIFY_POWERSHELL_SYNTAX.ps1') @()
  Step '1-FullFlutterTests' (Join-Path $Root 'RUN_ALL_TESTS.ps1') @()
  if (-not (Test-Path $dist)) { New-Item -ItemType Directory -Force -Path $dist | Out-Null }
  # Prevent previous runs from satisfying installation gates.
  Remove-Item -Path (Join-Path $dist 'install-ok-android-mobile.json') -Force -ErrorAction SilentlyContinue
  Remove-Item -Path (Join-Path $dist 'install-ok-android-tv.json') -Force -ErrorAction SilentlyContinue
  $mobileArgs = @('-SkipTests')
  if ($MobileSerial) { $mobileArgs += @('-DeviceSerial',$MobileSerial) }
  Step '2-AndroidMobile-Build-Then-OptionalInstall' (Join-Path $Root 'BUILD_ANDROID_MOBILE.ps1') $mobileArgs
  $tvArgs = @('-SkipTests')
  if ($TvSerial) { $tvArgs += @('-DeviceSerial',$TvSerial) }
  Step '3-AndroidTV-Build-Then-OptionalInstall' (Join-Path $Root 'BUILD_ANDROID_TV.ps1') $tvArgs
  Step '4-Windows-Build-Installer' (Join-Path $Root 'BUILD_WINDOWS_INSTALLER.ps1') @('-SkipTests')
  Step '5-Windows-Installer-Install-Launch' (Join-Path $Root 'VERIFY_WINDOWS_INSTALLER.ps1') @()
  $script:stage = '6-CheckInstallGate'
  if (-not (CheckReceipt 'android-mobile') -or -not (CheckReceipt 'android-tv')) {
    Write-Host 'Build stages completed. Phone or TV install not verified; GitHub push BLOCKED.' -ForegroundColor Yellow
    Write-Host 'Connect device later, then run INSTALL_BUILT_ANDROID.ps1 -Target mobile / -Target tv.' -ForegroundColor Yellow
    exit 0
  }
  $gate = Join-Path $dist 'github-ready-gate.json'
  $token = [guid]::NewGuid().ToString('N')
  @{ passed=$true; token=$token; version='0.1.2+3'; time=(Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content -Path $gate -Encoding UTF8
  if ($NoPush) {
    Write-Host 'All automated gates passed; -NoPush selected.' -ForegroundColor Green
  } else {
    Step '7-GitHub-Push-main' (Join-Path $Root 'PUSH_AFTER_VERIFIED.ps1') @('-VerificationToken',$token)
  }
  Write-Host 'Automated gates completed. Manual Cast/codec/TV checks still needed.' -ForegroundColor Yellow
} catch {
  New-Item -ItemType Directory -Force -Path $failureDir | Out-Null
  $log = Join-Path $failureDir 'FAILED_FULL_PIPELINE-v0.1.2+3.log'
  @("Stage: $script:stage", "Error: $($_.Exception.Message)", "Stack: $($_.ScriptStackTrace)") | Set-Content -Path $log -Encoding UTF8
  Write-Host "FAILED: $script:stage - $($_.Exception.Message). GitHub push blocked." -ForegroundColor Red
  Write-Host "Diagnostic log: $log" -ForegroundColor Red
  exit 1
}
