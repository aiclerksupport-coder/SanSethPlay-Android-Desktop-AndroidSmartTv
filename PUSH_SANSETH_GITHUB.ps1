# SanSeth Play v0.1.0+1 - Publish current local source while keeping existing remote history.
# Run from the project directory, with this script saved in that directory.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = 'https://github.com/aiclerksupport-coder/SanSethPlay-Android-Desktop-AndroidSmartTv.git'
$project = $PSScriptRoot
$stage = Join-Path ([IO.Path]::GetTempPath()) ('sanseth-github-push-' + [guid]::NewGuid().ToString('N'))
$logDir = Join-Path $project 'failure-logs'
$logPath = Join-Path $logDir 'FAILED_GITHUB_PUSH-v0.1.0+1.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$transcript = $false
try {
    Start-Transcript -Path $logPath -Force | Out-Null
    $transcript = $true
    Write-Host 'SanSeth Play source publishing - v0.1.0+1' -ForegroundColor Cyan
    if (!(Test-Path (Join-Path $project 'pubspec.yaml')) -or !(Test-Path (Join-Path $project 'lib'))) {
        throw 'Run this script from the root of SanSeth-Play-v0.1.0 (pubspec.yaml and lib must exist).'
    }
    if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is missing. Install Git for Windows first.' }
    & git --version
    if ($LASTEXITCODE -ne 0) { throw 'git --version failed.' }
    & git clone --branch main --single-branch $repo $stage
    if ($LASTEXITCODE -ne 0) { throw 'Clone failed. Sign in to GitHub through Git Credential Manager and retry.' }

    # Copy only source files and necessary native runners. Never copy Git metadata, builds, device secrets or logs.
    $excludeDirs = @('.git','.dart_tool','.gradle','.idea','.vs','.vscode','build','dist','failure-logs','coverage','.pub-cache','.pub','.local-config','node_modules','ephemeral','.plugin_symlinks','Release','Debug','x64','x86','CMakeFiles')
    $excludeFiles = @('*.log','*.tmp','*.part','*.sqlite','*.sqlite3','*.db','*.db-*','*.jks','*.keystore','*.p12','*.pfx','*.pem','*.key','*.cer','*.crt','*.mobileprovision','*.apk','*.aab','*.exe','*.msi','*.msix','*.zip','*.7z','*.rar','.env','.env.*','key.properties','local.properties','google-services.json','GoogleService-Info.plist','firebase-build.json','secrets.json','credentials.json','*.user','*.suo')
    $robocopyArgs = @($project,$stage,'/E','/R:1','/W:1','/NP','/XD') + $excludeDirs + @('/XF') + $excludeFiles
    Write-Host 'Copying approved source into a fresh clone...' -ForegroundColor Cyan
    & robocopy @robocopyArgs
    $rc = $LASTEXITCODE
    if ($rc -ge 8) { throw "robocopy failed with code $rc" }

    # The earlier project .gitignore omitted android/ and windows/ wholesale.
    # Retain source runners; exclude only build/generated/sensitive material.
    $ignorePath = Join-Path $stage '.gitignore'
    if (Test-Path $ignorePath) {
        $lines = @(Get-Content -LiteralPath $ignorePath)
        $lines = @($lines | Where-Object { $_.Trim() -notin @('android/','windows/') })
        [IO.File]::WriteAllLines($ignorePath, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))
    }
    Add-Content -Path $ignorePath -Encoding UTF8 -Value @'

# Native source is tracked; native generated caches and user-local settings are not.
android/.gradle/
android/local.properties
android/key.properties
android/**/build/
android/.cxx/
windows/flutter/ephemeral/
windows/**/CMakeFiles/
windows/**/build/
windows/.vs/
*.obj
*.pdb
*.ilk
*.tlog
*.lastbuildstate
*.VC.db
*.VC.opendb
*.exe
*.dll
*.msi
*.msix
*.apk
*.aab
'@

    & git -C $stage add -A
    if ($LASTEXITCODE -ne 0) { throw 'git add failed.' }
    $paths = @(& git -C $stage diff --cached --name-only)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect staged paths.' }
    if ($paths.Count -eq 0) {
        Write-Host 'No source changes to push; GitHub already matches staged source.' -ForegroundColor Green
    } else {
        $blocked = @($paths | Where-Object { $_ -match '(?i)(^|/)(\.env(\.|$)|local\.properties$|key\.properties$|google-services\.json$|secrets\.json$|credentials\.json$|firebase-build\.json$|failure-logs/|dist/|build/|\.dart_tool/|\.gradle/)|\.(apk|aab|exe|msi|msix|zip|jks|keystore|p12|pfx|pem|key|sqlite|db|log)$' })
        if ($blocked.Count -gt 0) { throw ('Unsafe staged paths detected: ' + ($blocked -join ', ')) }
        Write-Host ('Staged files: ' + $paths.Count) -ForegroundColor Cyan
        & git -C $stage diff --cached --stat
        if ($LASTEXITCODE -ne 0) { throw 'Could not generate staged diff summary.' }
        $author = & git -C $stage config user.name
        $email = & git -C $stage config user.email
        if ([string]::IsNullOrWhiteSpace($author) -or [string]::IsNullOrWhiteSpace($email)) {
            throw 'Git author is not configured. Set git config --global user.name and user.email on this laptop, then retry.'
        }
        & git -C $stage commit -m 'SanSeth Play v0.1.0+1: Flutter source, Android mobile and Android TV, Windows scaffold'
        if ($LASTEXITCODE -ne 0) { throw 'git commit failed.' }
        & git -C $stage push origin main
        if ($LASTEXITCODE -ne 0) { throw 'git push failed. Remote may have changed; inspect the log and retry without force.' }
        Write-Host 'SUCCESS: Source pushed to GitHub main.' -ForegroundColor Green
    }
    & git -C $stage rev-parse HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Could not get final commit SHA.' }
    Write-Host 'https://github.com/aiclerksupport-coder/SanSethPlay-Android-Desktop-AndroidSmartTv' -ForegroundColor Cyan
    Stop-Transcript | Out-Null
    $transcript = $false
    Remove-Item $logPath -Force -ErrorAction SilentlyContinue
    exit 0
} catch {
    Write-Host ('FAILED: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Full diagnostic log: ' + $logPath) -ForegroundColor Yellow
    exit 1
} finally {
    if ($transcript) { Stop-Transcript | Out-Null }
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
}
