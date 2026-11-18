# SanSeth Play - one-line Windows installer build, with tests and failure-only logs.
# Requires Flutter + Visual Studio C++ + Inno Setup 6 (ISCC.exe).
[CmdletBinding()]
param([switch]$SkipTests, [string]$IsccPath = '')
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root
$version = 'v0.1.3+4'
$failureDir = Join-Path $Root 'failure-logs'
$buffer = New-Object 'System.Collections.Generic.List[string]'
function Run-Stage([string]$Name, [string]$File, [string[]]$ArgsList) {
  Write-Host "`n==== $Name ====" -ForegroundColor Cyan
  Write-Host "> $File $($ArgsList -join ' ')"
  $global:LASTEXITCODE = 0
  & $File @ArgsList 2>&1 | ForEach-Object {
    $line = [string]$_
    Write-Host $line
    $buffer.Add($line)
    if ($buffer.Count -gt 12000) { $buffer.RemoveAt(0) }
  }
  if ($LASTEXITCODE -ne 0) { throw "$Name failed ($LASTEXITCODE)" }
}
try {
  Run-Stage 'Windows C++ toolchain preflight' 'powershell.exe' @(
    '-NoProfile','-ExecutionPolicy','Bypass','-File',
    (Join-Path $Root 'scripts/VERIFY_WINDOWS_TOOLCHAIN.ps1'))
  # Use established pipeline to create complete Windows portable folder.
  $pipeline = Join-Path $Root 'BUILD_WINDOWS.ps1'
  $argsList = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$pipeline)
  if ($SkipTests) { $argsList += '-SkipTests' }
  Run-Stage 'Flutter tests and Windows release' 'powershell.exe' $argsList
  $compiler = $IsccPath
  if ([string]::IsNullOrWhiteSpace($compiler)) {
    $found = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
    if ($found) { $compiler = $found.Source }
    else {
      $defaultPath = Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'
      if (Test-Path $defaultPath) { $compiler = $defaultPath }
    }
  }
  if (-not $compiler -or -not (Test-Path $compiler)) {
    throw 'Inno Setup 6 ISCC.exe missing. Install Inno Setup 6, or pass -IsccPath.'
  }
  $portable = Join-Path $Root "dist\SanSeth-Play-$version-Windows"
  $exe = Get-ChildItem $portable -Filter '*.exe' -File | Select-Object -First 1
  if (-not $exe) { throw 'No Windows executable in full release folder.' }
  $installerDir = Join-Path $Root 'dist\Windows-Installer'
  New-Item -ItemType Directory -Force -Path $installerDir | Out-Null
  $iss = Join-Path $env:TEMP 'SanSethPlayAutoInstaller.iss'
  # Keep ALL Flutter DLLs/data files alongside EXE. Never distribute only the EXE.
  $portableEscaped = $portable.Replace('"','')
  $installerEscaped = $installerDir.Replace('"','')
  $content = @"
[Setup]
AppId={{C96E1321-81E2-4CE9-A20A-E6DD50A5E117}
AppName=SanSeth Play
AppVersion=0.1.1
AppPublisher=Kalpesh Chhabhaiya
DefaultDirName={autopf}\SanSeth Play
DefaultGroupName=SanSeth Play
OutputDir=$installerEscaped
OutputBaseFilename=SanSeth-Play-v0.1.3+4-Windows-Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
UninstallDisplayIcon={app}\$($exe.Name)
WizardStyle=modern
[Files]
Source: "$portableEscaped\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
[Icons]
Name: "{autoprograms}\SanSeth Play"; Filename: "{app}\$($exe.Name)"
Name: "{autodesktop}\SanSeth Play"; Filename: "{app}\$($exe.Name)"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Desktop shortcut"; GroupDescription: "Additional icons:"
[Run]
Filename: "{app}\$($exe.Name)"; Description: "Launch SanSeth Play"; Flags: nowait postinstall skipifsilent
"@
  [IO.File]::WriteAllText($iss,$content)
  Run-Stage 'Create Windows Setup installer' $compiler @('/Qp',$iss)
  Write-Host "SUCCESS: Windows installer: $installerDir" -ForegroundColor Green
  Write-Host 'Installer is NOT signed. Windows SmartScreen may warn. Code signing required for public distribution.' -ForegroundColor Yellow
} catch {
  New-Item -ItemType Directory -Force -Path $failureDir | Out-Null
  $failure = Join-Path $failureDir 'FAILED_windows_installer-v0.1.3+4.log'
  @("Reason: $($_.Exception.Message)","Stack: $($_.ScriptStackTrace)",'') + $buffer |
    Set-Content -Path $failure -Encoding UTF8
  Write-Host "FAILED. Diagnostics: $failure" -ForegroundColor Red
  exit 1
}
