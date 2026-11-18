# Invoke only from BUILD_TEST_INSTALL_GITHUB.ps1 after ALL gates pass.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$VerificationToken)
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$Repo = 'https://github.com/aiclerksupport-coder/SanSethPlay-Android-Desktop-AndroidSmartTv.git'
$GitDir = Join-Path $Root '.git'
$TokenFile = Join-Path $Root 'dist\github-ready-gate.json'
if (-not (Test-Path $TokenFile)) { throw 'Verification gate missing; run BUILD_TEST_INSTALL_GITHUB.ps1 first.' }
$gate = Get-Content -Raw $TokenFile | ConvertFrom-Json
if ($gate.token -ne $VerificationToken -or $gate.passed -ne $true -or $gate.version -ne '0.1.1+2') {
  throw 'Verification gate invalid or stale.'
}
if (Test-Path $GitDir) { throw 'Existing .git folder detected. Refusing to overwrite history; use a clean extracted ZIP.' }
$stamp = Get-Date
if (($stamp - [datetime]$gate.time).TotalMinutes -gt 30) { throw 'Verification gate expired. Run full command again.' }
$clone = Join-Path $env:TEMP ('sanseth-git-stage-' + [guid]::NewGuid().ToString('N'))
$excludeDirs = @('.git','android','windows','linux','macos','ios','web','build','dist','failure-logs','.dart_tool','.pub-cache','.pub','.idea')
$excludeFiles = @('*.log','*.db','*.sqlite','*.sqlite3','*.jks','*.keystore','*.pem','*.p12','*.pfx','.env','.env.*','key.properties','local.properties','google-services.json','GoogleService-Info.plist')
try {
  & git clone --branch main --single-branch $Repo $clone
  if ($LASTEXITCODE -ne 0) { throw 'Git clone failed; authenticate with Git Credential Manager/GitHub CLI.' }
  $robocopyArgs = @($Root,$clone,'/E','/R:1','/W:1','/NFL','/NDL','/NJH','/NJS','/NP','/XD') + ($excludeDirs | ForEach-Object { Join-Path $Root $_ }) + @('/XF') + $excludeFiles
  & robocopy @robocopyArgs | Out-Host
  if ($LASTEXITCODE -gt 7) { throw "Robocopy failed: $LASTEXITCODE" }
  Push-Location $clone
  try {
    & git add -A
    if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
    $paths = @(& git diff --cached --name-only)
    foreach ($path in $paths) {
      if ($path -match '(^|/)(\.env|key\.properties|local\.properties|google-services\.json|secrets\.json|credentials\.json)$|\.(jks|keystore|p12|pem|pfx|key)$|(^|/)(dist|build|failure-logs|\.dart_tool)/') {
        throw "SECRET/ARTIFACT REJECTED: $path"
      }
    }
    & git diff --cached --check
    if ($LASTEXITCODE -ne 0) { throw 'git diff --check failed' }
    if ($paths.Count -eq 0) { Write-Host 'Nothing new to push.'; return }
    & git commit -m 'SanSeth Play v0.1.1+2: three-platform verified source'
    if ($LASTEXITCODE -ne 0) { throw 'Git commit failed. Configure git user.name and user.email.' }
    & git push origin main
    if ($LASTEXITCODE -ne 0) { throw 'GitHub push failed. Remote branch may have moved; refusing force push.' }
    Write-Host 'SUCCESS: GitHub main updated after all verification gates.' -ForegroundColor Green
  } finally { Pop-Location }
} finally {
  if (Test-Path $clone) { Remove-Item -LiteralPath $clone -Recurse -Force -ErrorAction SilentlyContinue }
}
