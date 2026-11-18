# Smoke test real Inno Setup installation into an isolated per-user directory.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$Root=$PSScriptRoot
$setup=Join-Path $Root 'dist\Windows-Installer\SanSeth-Play-v0.1.1+2-Windows-Setup.exe'
$install=Join-Path $Root 'dist\Windows-Installer-Smoke-Install'
$logDir=Join-Path $Root 'failure-logs'
try {
  if (-not (Test-Path $setup)) { throw "Installer missing: $setup" }
  if (Test-Path $install) { throw 'Old smoke installation exists; remove safely before retrying.' }
  New-Item -ItemType Directory -Force -Path $install | Out-Null
  Write-Host "> $setup /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR=$install"
  $process=Start-Process -FilePath $setup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=$install") -PassThru -Wait
  if ($process.ExitCode -ne 0) { throw "Installer exit code $($process.ExitCode)" }
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'VERIFY_WINDOWS_LAUNCH.ps1') -ReleaseFolder $install
  if ($LASTEXITCODE -ne 0) { throw 'Installed Windows app launch smoke check failed' }
  Write-Host 'Windows Setup installed and app startup smoke passed.' -ForegroundColor Green
} catch {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
  "Windows installer smoke failed: $($_.Exception.Message)" | Set-Content (Join-Path $logDir 'FAILED_windows_setup_install-v0.1.1+2.log')
  throw
}
