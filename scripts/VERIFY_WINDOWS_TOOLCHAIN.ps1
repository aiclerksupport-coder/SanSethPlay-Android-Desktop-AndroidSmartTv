#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (-not (Test-Path -LiteralPath $vswhere)) {
  Write-Host 'ERROR: Visual Studio Installer/vswhere is missing.' -ForegroundColor Red
  Write-Host 'Install Visual Studio with Desktop development with C++ workload.' -ForegroundColor Yellow
  Write-Host 'Official instructions: https://docs.flutter.dev/platform-integration/windows/setup'
  exit 1
}
$installation = & $vswhere -latest -products '*' -version 16 -property installationPath `
  -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    Microsoft.VisualStudio.Component.VC.CMake.Project `
    Microsoft.VisualStudio.Workload.NativeDesktop
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace(($installation -join '').Trim())) {
  Write-Host 'ERROR: Flutter Windows C++ build toolchain is unavailable.' -ForegroundColor Red
  Write-Host 'Open Visual Studio Installer > Modify > Desktop development with C++.' -ForegroundColor Yellow
  Write-Host 'Include MSVC x64/x86 tools, CMake tools for Windows, and Windows 10/11 SDK.'
  Write-Host 'Then run: flutter doctor -v'
  Write-Host 'Official: https://docs.flutter.dev/platform-integration/windows/setup'
  exit 1
}
Write-Host ('PASS: Windows C++ toolchain at ' + (($installation | Select-Object -First 1).Trim())) -ForegroundColor Green
exit 0
