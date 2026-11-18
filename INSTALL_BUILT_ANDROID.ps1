# Install existing release APK - never rebuild; auto-select ONE matching target after device connection.
[CmdletBinding()]
param([ValidateSet('mobile','tv')][string]$Target='mobile',[string]$DeviceSerial='')
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$apk=Join-Path $Root 'build/app/outputs/flutter-apk/app-release.apk'
$dist=Join-Path $Root 'dist'
$logDir=Join-Path $Root 'failure-logs'
try {
  if (-not (Test-Path $apk)) { throw 'Release APK not found. Build first using BUILD_ANDROID_MOBILE.ps1 -SkipInstall.' }
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) { throw 'ADB missing. Build already exists; install requires Android platform tools.' }
  $raw=@(& adb devices -l 2>&1)
  if ($LASTEXITCODE -ne 0) { throw 'ADB devices command failed.' }
  $matching=@()
  foreach($line in $raw) {
    if ([string]$line -notmatch '^([^\s]+)\s+device(?:\s|$)') { continue }
    $serial=$Matches[1]
    $features=(& adb -s $serial shell pm list features 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { continue }
    $isTv= $features -match 'android\.software\.leanback'
    if (($Target -eq 'tv') -eq $isTv) { $matching += $serial }
  }
  if ($DeviceSerial) {
    if ($matching -notcontains $DeviceSerial) { throw 'Selected device not connected or wrong device type.' }
    $serial=$DeviceSerial
  } elseif ($matching.Count -eq 1) {
    $serial=$matching[0]
  } elseif ($matching.Count -eq 0) {
    throw "No authorized $Target device. APK is built and waiting; connect device then rerun this install command."
  } else {
    throw "Multiple matching devices. Pass -DeviceSerial with one of: $($matching -join ', ')"
  }
  Write-Host "Installing built APK on $serial ..." -ForegroundColor Cyan
  & adb -s $serial install -r $apk
  if ($LASTEXITCODE -ne 0) { throw "ADB install failed with $LASTEXITCODE" }
  $smoke=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $Root 'VERIFY_ANDROID_LAUNCH.ps1'),'-DeviceSerial',$serial)
  if ($Target -eq 'tv') { $smoke += '-Tv' }
  & powershell.exe @smoke
  if ($LASTEXITCODE -ne 0) { throw "Launch smoke failed with $LASTEXITCODE" }
  New-Item -ItemType Directory -Force -Path $dist | Out-Null
  $kind=if($Target -eq 'tv') {'android-tv'} else {'android-mobile'}
  @{ target=$kind; serial=$serial; apkSha256=(Get-FileHash $apk -Algorithm SHA256).Hash; timestamp=(Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content -Path (Join-Path $dist "install-ok-$kind.json") -Encoding UTF8
  Write-Host 'Install and launch smoke PASS. Real playback still requires device test.' -ForegroundColor Green
  exit 0
} catch {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  $log=Join-Path $logDir 'FAILED_postbuild_install-v0.1.1+2.log'
  @($_.Exception.Message,$_.ScriptStackTrace) | Set-Content -Path $log -Encoding UTF8
  Write-Host "INSTALL FAILED: $($_.Exception.Message) | log: $log" -ForegroundColor Red
  exit 1
}
