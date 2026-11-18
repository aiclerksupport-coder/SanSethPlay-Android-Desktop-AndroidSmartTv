# SanSeth Play v0.1.3+4 - Windows PowerShell 5.1 or 7
# All commands and verbose output are visible in the VS Code terminal.
# Diagnostic logs are written ONLY when a step fails.
[CmdletBinding()]
param(
  [ValidateSet('all','android-mobile','android-tv','windows','tests')][string]$Target = 'all',
  [string]$DeviceSerial = '',
  [string]$TvHost = '',
  [switch]$SkipInstall,
  [switch]$SkipTests
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root
$Version = 'v0.1.3+4'
$LogDir = Join-Path $Root 'failure-logs'
$DistDir = Join-Path $Root 'dist'
$script:CurrentStage = 'startup'
trap {
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  $stopLog = Join-Path $LogDir ('FAILED_pipeline-' + $Version.Replace('+','_') + '.log')
  @('Target: ' + $Target, 'Stage: ' + $script:CurrentStage, 'Error: ' + $_.Exception.Message, 'Details: ' + $_.ScriptStackTrace) | Set-Content -Path $stopLog -Encoding UTF8
  Write-Host ('Pipeline stopped: ' + $_.Exception.Message + ' | ' + $stopLog) -ForegroundColor Red
  exit 1
}
New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

function Invoke-Checked {
  param([string]$Name, [string]$File, [string[]]$Arguments)
  $script:CurrentStage = $Name
  Write-Host "`n========== $Name ==========" -ForegroundColor Cyan
  Write-Host ('> ' + $File + ' ' + ($Arguments -join ' ')) -ForegroundColor Cyan
  New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
  $safeName = $Name -replace '[^a-zA-Z0-9_-]', '_'
  $failureFile = Join-Path $LogDir ('FAILED_' + $safeName + '-' + $Version.Replace('+','_') + '.log')
  $liveFile = Join-Path $LogDir ('RUNNING_' + $safeName + '-' + $Version.Replace('+','_') + '.tmp.log')
  Remove-Item -LiteralPath $failureFile -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $liveFile -Force -ErrorAction SilentlyContinue
  $writer = $null
  $code = 1
  $failure = ''
  try {
    $writer = New-Object System.IO.StreamWriter($liveFile, $false, (New-Object System.Text.UTF8Encoding($true)))
    $writer.AutoFlush = $true
    $writer.WriteLine('Step: ' + $Name)
    $writer.WriteLine('Command: ' + $File + ' ' + ($Arguments -join ' '))
    $writer.WriteLine('Started: ' + (Get-Date).ToString('o'))
    $global:LASTEXITCODE = 0
    $oldPreference = $ErrorActionPreference
    try {
      # Native stderr is a PowerShell error record in Windows PowerShell 5.1.
      # Do not throw before full transcript is finalized.
      $ErrorActionPreference = 'Continue'
      & $File @Arguments 2>&1 | ForEach-Object {
        $line = $_.ToString()
        Write-Host $line
        $writer.WriteLine($line)
      }
      $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $oldPreference }
    if ($null -eq $code) { $code = 1 }
    $writer.WriteLine('Exit code: ' + $code)
  } catch {
    $failure = $_.Exception.Message
    Write-Host ('Command exception: ' + $failure) -ForegroundColor Red
    if ($null -ne $writer) {
      $writer.WriteLine('Command exception: ' + $failure)
      $writer.WriteLine($_.ScriptStackTrace)
    }
    $code = 1
  } finally {
    if ($null -ne $writer) { $writer.Flush(); $writer.Dispose() }
  }
  if ($code -ne 0) {
    if (Test-Path -LiteralPath $liveFile) { Move-Item -LiteralPath $liveFile -Destination $failureFile -Force }
    else { ('Step failed before output initialization: ' + $Name + ' ' + $failure) | Set-Content -LiteralPath $failureFile -Encoding UTF8 }
    Write-Host ('FAIL: ' + $Name + ' | Complete verbose log: ' + $failureFile) -ForegroundColor Red
    throw "$Name exited with code $code; log: $failureFile"
  }
  Remove-Item -LiteralPath $liveFile -Force -ErrorAction SilentlyContinue
  Write-Host "PASS: $Name" -ForegroundColor Green
}
function Require-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Missing '$Name'. Install/configure it and open a fresh VS Code terminal."
  }
}
function Get-DeviceList {
  # ADB access happens ONLY during the post-build install stage.
  $raw = @(& adb devices -l 2>&1)
  if ($LASTEXITCODE -ne 0) { throw 'ADB unavailable during install. APK build already finished.' }
  $devices = @()
  foreach ($line in $raw) {
    if ([string]$line -match '^([^\s]+)\s+device(?:\s|$)') { $devices += $Matches[1] }
  }
  return $devices
}
function Confirm-AndroidType([string]$Serial, [bool]$Tv) {
  $features = (& adb -s $Serial shell pm list features 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { throw "Cannot read Android features from $Serial" }
  $isTv = $features -match 'android\.software\.leanback'
  if ($Tv -and -not $isTv) { throw "Device $Serial is not Android TV." }
  if (-not $Tv -and $isTv) { throw "Device $Serial is Android TV, not phone." }
}
function Get-SelectedSerial([bool]$Tv) {
  $devices = @(Get-DeviceList)
  $matching = @()
  foreach ($serial in $devices) {
    $features = (& adb -s $serial shell pm list features 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { continue }
    $isTv = $features -match 'android\.software\.leanback'
    if ($isTv -eq $Tv) { $matching += $serial }
  }
  if ($DeviceSerial) {
    if ($matching -notcontains $DeviceSerial) {
      throw "Requested device '$DeviceSerial' not authorized/connected for this target."
    }
    return $DeviceSerial
  }
  if ($matching.Count -gt 1) {
    throw "Multiple matching devices: $($matching -join ', '). Supply -DeviceSerial during install."
  }
  if ($matching.Count -eq 0) { return '' }
  return [string]$matching[0]
}
function Prepare-Project {
  Require-Command 'flutter'; Require-Command 'dart'
  Invoke-Checked '01_flutter_doctor' 'flutter' @('doctor','-v')
  Invoke-Checked '02_prepare_platforms' 'powershell.exe' @('-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $Root 'tool/prepare_platforms.ps1'))
  Invoke-Checked '03_flutter_pub_get' 'flutter' @('pub','get')
}
function Test-Project {
  # Apply analyzer-supported AST fixes to the first-run Dart source.
  # This is intentionally before format and analyze; never suppress diagnostics.
  Invoke-Checked '03b_dart_fix_apply' 'dart' @('fix','--apply')
  Invoke-Checked '04_dart_format_apply' 'dart' @('format','lib','test')
  Invoke-Checked '04b_dart_format_verify' 'dart' @('format','--output=none','--set-exit-if-changed','lib','test')
  Invoke-Checked '05_flutter_analyze' 'flutter' @('analyze','--no-pub','--verbose')
  Invoke-Checked '06_flutter_test' 'flutter' @('test','--verbose','--reporter','expanded','-j','1')
}
function Build-Android([bool]$Tv) {
  $name = if ($Tv) {'android-tv'} else {'android-mobile'}
  # Resolve native player artifacts before Gradle configuration (where upstream has no retry).
  Invoke-Checked '06c_prefetch_media_kit' 'powershell.exe' @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',
    (Join-Path $Root 'scripts/PREFETCH_MEDIA_KIT_ANDROID.ps1'), '-ProjectRoot', $Root)
  Invoke-Checked "07_build_$name" 'flutter' @('build','apk','--release','--verbose')
  $apk = Join-Path $Root 'build/app/outputs/flutter-apk/app-release.apk'
  if (-not (Test-Path $apk)) { throw "Release APK missing: $apk" }
  $destination = Join-Path $DistDir "SanSeth-Play-$Version-$name.apk"
  Copy-Item $apk $destination -Force
  Write-Host "Build artifact: $destination" -ForegroundColor Green
  if ($SkipInstall) { Write-Host 'Build complete. Install explicitly skipped.'; return }
  # No ADB requirement and no device enumeration until AFTER the APK exists.
  if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Host 'APK BUILD SUCCESS. ADB unavailable: installation skipped; no install verification.' -ForegroundColor Yellow
    return
  }
  if ($TvHost) {
    if (-not $Tv) { throw '-TvHost is only allowed for android-tv.' }
    Invoke-Checked '08_adb_connect_tv' 'adb' @('connect',$TvHost)
  }
  $serial = Get-SelectedSerial $Tv
  if (-not $serial) {
    Write-Host "APK BUILD SUCCESS. No authorized $name device connected: install skipped. Connect later and run INSTALL_BUILT_ANDROID.ps1." -ForegroundColor Yellow
    return
  }
  Confirm-AndroidType $serial $Tv
  Invoke-Checked "09_install_$name" 'adb' @('-s',$serial,'install','-r',$apk)
  $smokeArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',
    (Join-Path $Root 'VERIFY_ANDROID_LAUNCH.ps1'),'-DeviceSerial',$serial)
  if ($Tv) { $smokeArgs += '-Tv' }
  Invoke-Checked "10_launch_smoke_$name" 'powershell.exe' $smokeArgs
  $receipt = Join-Path $DistDir ("install-ok-$name.json")
  @{ serial=$serial; target=$name; apkSha256=(Get-FileHash $apk -Algorithm SHA256).Hash; timestamp=(Get-Date).ToString('o') } |
    ConvertTo-Json | Set-Content -LiteralPath $receipt -Encoding UTF8
  Write-Host "Installed and launch-smoke checked on $serial (playback still requires manual verification)." -ForegroundColor Green
}
function Build-Windows {
  Invoke-Checked '06b_windows_toolchain_preflight' 'powershell.exe' @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',
    (Join-Path $Root 'scripts/VERIFY_WINDOWS_TOOLCHAIN.ps1'))
  Invoke-Checked '07_build_windows' 'flutter' @('build','windows','--release','--verbose')
  $release = Join-Path $Root 'build/windows/x64/runner/Release'
  if (-not (Test-Path $release)) { throw "Windows Release folder not found: $release" }
  $destination = Join-Path $DistDir "SanSeth-Play-$Version-Windows"
  if (Test-Path $destination) { Remove-Item -Recurse -Force $destination }
  Copy-Item -Recurse $release $destination
  $exe = Get-ChildItem $destination -Filter '*.exe' -File | Select-Object -First 1
  if (-not $exe) { throw 'No Windows executable in Release folder' }
  Write-Host "Windows portable installation: $destination" -ForegroundColor Green
  Write-Host "Run $($exe.FullName) - keep all DLLs and data folder together." -ForegroundColor Yellow
  # Windows startup smoke tests the full package for an immediate crash.
  # This is not a video playback or UI performance certification.
  Invoke-Checked '08_windows_launch_smoke' 'powershell.exe' @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',
    (Join-Path $Root 'VERIFY_WINDOWS_LAUNCH.ps1'),'-ReleaseFolder',$destination)
}
Prepare-Project
if (-not $SkipTests) { Test-Project }
switch ($Target) {
  'all' {
    Build-Android $false
    Build-Windows
    Write-Host 'Android TV uses the same APK; install separately with BUILD_ANDROID_TV.ps1.' -ForegroundColor Yellow
  }
  'android-mobile' { Build-Android $false }
  'android-tv' { Build-Android $true }
  'windows' { Build-Windows }
  'tests' { Write-Host 'All requested static and unit tests finished.' }
}
Write-Host "`nSUCCESS - Target: $Target" -ForegroundColor Green
exit 0
