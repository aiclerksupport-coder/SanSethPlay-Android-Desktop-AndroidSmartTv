# SanSeth Play - prefetch official pinned media-kit Android native libraries.
# Windows PowerShell 5.1/7; no Pub cache edits, no bypass of native integrity checks.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ProjectRoot)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$release = 'v1.1.7'
$baseUrl = 'https://github.com/media-kit/libmpv-android-video-build/releases/download/' + $release
$target = Join-Path $ProjectRoot ('build/media_kit_libs_android_video/' + $release)
$cache = Join-Path $env:LOCALAPPDATA ('SanSethPlay/media-kit/' + $release)
$files = @(
  @{Name='default-arm64-v8a.jar'; Md5='83df25b61193af8fa815e373143ac9af'},
  @{Name='default-armeabi-v7a.jar'; Md5='22e21526fefc0a2b8f17adbec9f57590'},
  @{Name='default-x86_64.jar'; Md5='6fa26bf0459b11f1c0b0dbc29e5b940d'},
  @{Name='default-x86.jar'; Md5='0d742b756dc9d1fcd84ea271d8b68f32'}
)
function Test-Verified([string]$Path,[string]$Expected) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
  try { return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLowerInvariant() -eq $Expected }
  catch { return $false }
}
New-Item -ItemType Directory -Force -Path $target,$cache | Out-Null
# Reuse an already verified JAR from another extracted source tree, if available.
# Only known direct sibling project paths are inspected; no arbitrary disk recursion.
$siblings = @()
$projectParent = Split-Path $ProjectRoot -Parent
$workspaceParent = Split-Path $projectParent -Parent
if (Test-Path -LiteralPath $workspaceParent) {
  $siblingRoots = @(Get-ChildItem -LiteralPath $workspaceParent -Directory -Filter 'SanSeth-Play-v0.1*' -ErrorAction SilentlyContinue)
  foreach ($folder in $siblingRoots) {
    $siblingProject = Join-Path $folder.FullName 'SanSeth-Play-v0.1.0'
    if ($siblingProject -ne $ProjectRoot) {
      $siblings += (Join-Path $siblingProject ('build/media_kit_libs_android_video/' + $release))
    }
  }
}
# TLS 1.2 is required by GitHub on older Windows PowerShell hosts.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
foreach ($item in $files) {
  $name = [string]$item.Name
  $md5 = [string]$item.Md5
  $dest = Join-Path $target $name
  if (Test-Verified $dest $md5) { Write-Host "Verified existing native JAR: $name" -ForegroundColor Green; continue }
  if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Force }
  $candidates = @((Join-Path $cache $name))
  foreach ($folder in $siblings) { $candidates += (Join-Path $folder $name) }
  $found = $false
  foreach ($candidate in $candidates) {
    if (Test-Verified $candidate $md5) {
      Copy-Item -LiteralPath $candidate -Destination $dest -Force
      Write-Host "Reused verified local native JAR: $name" -ForegroundColor Green
      $found = $true
      break
    }
  }
  if ($found) { continue }
  $url = "$baseUrl/$name"
  $staging = Join-Path $target ('.' + $name + '.partial')
  $lastError = ''
  for ($attempt=1; $attempt -le 4; $attempt++) {
    try {
      Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
      Write-Host "Fetching official media-kit $name (attempt $attempt/4)..." -ForegroundColor Cyan
      Invoke-WebRequest -Uri $url -OutFile $staging -UseBasicParsing -TimeoutSec 100 -MaximumRedirection 10 -ErrorAction Stop
      if (-not (Test-Verified $staging $md5)) { throw "Integrity check failed (MD5 mismatch) for $name" }
      Move-Item -LiteralPath $staging -Destination $dest -Force
      Copy-Item -LiteralPath $dest -Destination (Join-Path $cache $name) -Force
      Write-Host "Downloaded and verified: $name" -ForegroundColor Green
      $found = $true
      break
    } catch {
      $lastError = $_.Exception.Message
      Remove-Item -LiteralPath $staging -Force -ErrorAction SilentlyContinue
      Write-Warning "Official download attempt $attempt/4 failed for ${name}: $lastError"
      if ($attempt -lt 4) { Start-Sleep -Seconds ([Math]::Min(3*$attempt, 9)) }
    }
  }
  if (-not $found) {
    throw "Unable to fetch verified media-kit $name from $url; last error: $lastError. Check GitHub releases connectivity or use the same verified JAR cached from your previous successful build. No code or native checksum was modified."
  }
}
Write-Host 'PASS: Official media-kit Android JARs verified and ready for Gradle.' -ForegroundColor Green
