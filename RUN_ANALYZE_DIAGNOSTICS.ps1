# SanSeth Play v0.1.0+1 - live terminal output + guaranteed failure diagnostics.
# Compatible with Windows PowerShell 5.1. Invoke external commands with
# ErrorActionPreference=Continue so stderr/nonzero status cannot bypass log finalization.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
Set-Location -LiteralPath $root
$logDir = Join-Path $root 'failure-logs'
$full = Join-Path $logDir 'ANALYZE_FULL-v0.1.0+1.log'
$machine = Join-Path $logDir 'ANALYZE_MACHINE-v0.1.0+1.log'
$tmp = Join-Path $logDir 'ANALYZE_RUNNING-v0.1.0+1.tmp.log'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
# Remove stale output so an earlier run cannot be mistaken for this one.
Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $full -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $machine -Force -ErrorAction SilentlyContinue
$writer = $null
$exitCode = 1
try {
  $writer = New-Object System.IO.StreamWriter($tmp, $false, (New-Object System.Text.UTF8Encoding($true)))
  $writer.AutoFlush = $true
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Flutter command not found in PATH.' }
  if (-not (Get-Command dart -ErrorAction SilentlyContinue)) { throw 'Dart command not found in PATH.' }
  Write-Host 'RUNNING: flutter analyze --no-pub --verbose' -ForegroundColor Cyan
  $writer.WriteLine('Command: flutter analyze --no-pub --verbose')
  $writer.WriteLine('Started: ' + (Get-Date).ToString('o'))
  $oldPreference = $ErrorActionPreference
  try {
    # Windows PowerShell 5.1 treats redirected native stderr as an error record.
    # Continue (only inside this invocation) guarantees the pipeline reaches finalization.
    $ErrorActionPreference = 'Continue'
    & flutter analyze --no-pub --verbose 2>&1 | ForEach-Object {
      $line = $_.ToString()
      Write-Host $line
      $writer.WriteLine($line)
    }
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $oldPreference
  }
  if ($null -eq $exitCode) { $exitCode = 1 }
  $writer.WriteLine('Exit code: ' + $exitCode)
} catch {
  $message = 'ANALYZER ERROR: ' + $_.Exception.Message
  Write-Host $message -ForegroundColor Red
  if ($null -ne $writer) { $writer.WriteLine($message); $writer.WriteLine($_.ScriptStackTrace) }
  $exitCode = 1
} finally {
  if ($null -ne $writer) { $writer.Flush(); $writer.Dispose() }
}
if ($exitCode -eq 0) {
  Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  Write-Host 'PASS: flutter analyze --no-pub' -ForegroundColor Green
  exit 0
}
# Move the already-flushed full transcript BEFORE trying any secondary command.
if (Test-Path -LiteralPath $tmp) { Move-Item -LiteralPath $tmp -Destination $full -Force }
else { 'Analyzer stopped before log initialization.' | Set-Content -LiteralPath $full -Encoding UTF8 }
Write-Host ('FAIL: full verbose output saved: ' + $full) -ForegroundColor Red
# Machine-readable output is a second pass; failure must not hide FULL log.
$machineWriter = $null
try {
  $machineWriter = New-Object System.IO.StreamWriter($machine, $false, (New-Object System.Text.UTF8Encoding($true)))
  $machineWriter.AutoFlush = $true
  $oldPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & dart analyze --format machine lib test 2>&1 | ForEach-Object {
      $line = $_.ToString()
      Write-Host $line
      $machineWriter.WriteLine($line)
    }
    $machineExit = $LASTEXITCODE
  } finally { $ErrorActionPreference = $oldPreference }
  $machineWriter.WriteLine('Exit code: ' + $machineExit)
} catch {
  Write-Host ('Machine diagnostics error: ' + $_.Exception.Message) -ForegroundColor Yellow
  if ($null -ne $machineWriter) { $machineWriter.WriteLine($_.Exception.Message) }
} finally {
  if ($null -ne $machineWriter) { $machineWriter.Flush(); $machineWriter.Dispose() }
}
Write-Host ('Machine diagnostic file: ' + $machine) -ForegroundColor Yellow
exit 1
