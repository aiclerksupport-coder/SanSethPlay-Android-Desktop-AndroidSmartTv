# Windows portable exe smoke check; Windows only, run after BUILD_WINDOWS.ps1.
[CmdletBinding()]
param([string]$ReleaseFolder = '')
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$logDir = Join-Path $Root 'failure-logs'
$process = $null
try {
  if (-not $ReleaseFolder) { $ReleaseFolder = Join-Path $Root 'dist\SanSeth-Play-v0.1.0+1-Windows' }
  if (-not (Test-Path $ReleaseFolder)) { throw 'Windows release folder missing; run BUILD_WINDOWS.ps1' }
  $exe = Get-ChildItem $ReleaseFolder -Filter '*.exe' -File | Select-Object -First 1
  if (-not $exe) { throw 'Windows executable missing' }
  if (-not (Test-Path (Join-Path $ReleaseFolder 'data'))) { throw 'Flutter data folder missing' }
  if (-not (Test-Path (Join-Path $ReleaseFolder 'flutter_windows.dll'))) { throw 'Flutter runtime DLL missing' }
  Write-Host "> Start-Process `"$($exe.FullName)`"" -ForegroundColor Cyan
  $process = Start-Process -FilePath $exe.FullName -WorkingDirectory $ReleaseFolder -PassThru
  Start-Sleep -Seconds 6
  $process.Refresh()
  if ($process.HasExited) { throw "Process exited during startup (code $($process.ExitCode))" }
  Write-Host 'PASS: Windows process alive after 6 seconds.' -ForegroundColor Green
  Write-Host 'Manual check still required for stream playback, MediaSession, layout, and installer.' -ForegroundColor Yellow
} catch {
  New-Item -ItemType Directory -Path $logDir -Force | Out-Null
  @("Failure: $($_.Exception.Message)","Folder: $ReleaseFolder") | Set-Content (Join-Path $logDir 'FAILED_WINDOWS_LAUNCH-v0.1.0+1.log') -Encoding UTF8
  Write-Host "FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -ErrorAction SilentlyContinue }
}
