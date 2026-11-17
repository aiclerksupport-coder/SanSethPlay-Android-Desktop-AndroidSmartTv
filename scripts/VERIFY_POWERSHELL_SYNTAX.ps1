# SanSeth Play: validate every PowerShell script before any Flutter/build/install stage.
# Windows PowerShell 5.1 / PowerShell 7 compatible.
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$errorsFound = 0
$scriptFiles = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.ps1' -File -Recurse |
  Where-Object { $_.FullName -notmatch '[\\/](build|dist|\.dart_tool|\.git)[\\/]' })
foreach ($file in $scriptFiles) {
  $tokens = $null
  $parseErrors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $file.FullName, [ref]$tokens, [ref]$parseErrors)
  if ($null -ne $parseErrors -and $parseErrors.Count -gt 0) {
    $errorsFound++
    Write-Host "FAIL PowerShell parse: $($file.FullName)" -ForegroundColor Red
    foreach ($issue in $parseErrors) {
      Write-Host "  Line $($issue.Extent.StartLineNumber): $($issue.Message)" -ForegroundColor Red
    }
  }
}
if ($errorsFound -gt 0) {
  Write-Host "FAILED: $errorsFound PowerShell script(s) contain syntax errors." -ForegroundColor Red
  exit 1
}
Write-Host "PASS: $($scriptFiles.Count) PowerShell script(s) parsed." -ForegroundColor Green
exit 0
