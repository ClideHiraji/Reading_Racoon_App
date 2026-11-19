<#
.SYNOPSIS
    Keeps one Laravel background process alive on the home server (D-036).

.DESCRIPTION
    Runs `php artisan <Command>` in backend/, and starts it again whenever it
    stops: after a crash, a lost database connection, or the worker's own
    --max-time restart. Waits longer after quick repeated failures (5 s up to
    5 min) so a broken setup can't spin the CPU. Writes a dated log under
    backend/storage/logs/ and keeps 14 days of them.

    Started at boot by install-tasks.ps1 for:
      queue:work     the server replay and Gemini report jobs
      schedule:work  backups, pruning and the heartbeat

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File run-forever.ps1 -Command "queue:work --tries=5 --max-time=3600"
#>
param(
    [Parameter(Mandatory = $true)][string]$Command,
    [string]$Php = "C:\xampp\php\php.exe"
)

$ErrorActionPreference = "Continue"
$backend = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$name = ($Command -split " ")[0] -replace "[^a-z]", "-"
$logDir = Join-Path $backend "storage\logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null   # a fresh checkout may not have it yet
$wait = 5

while ($true) {
    $log = Join-Path $logDir ("{0}-{1:yyyy-MM-dd}.log" -f $name, (Get-Date))
    Get-ChildItem $logDir -Filter "$name-*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-14) } | Remove-Item -ErrorAction SilentlyContinue

    $started = Get-Date
    Add-Content $log ("{0:s} starting: php artisan {1}" -f $started, $Command)
    $arguments = @("artisan") + ($Command -split " ")
    # Each line reaches the log as it is printed, so a stuck worker shows
    # what it was doing (not only after it exits).
    Push-Location $backend
    & $Php @arguments 2>&1 | ForEach-Object { "$_" } | Add-Content -Path $log -Encoding UTF8
    $code = $LASTEXITCODE
    Pop-Location
    Add-Content $log ("{0:s} stopped with exit code {1}" -f (Get-Date), $code)

    # A run that lasted a while was healthy: restart quickly. Repeated quick
    # failures back off, so a broken database doesn't spin the laptop's CPU.
    if (((Get-Date) - $started).TotalMinutes -ge 5) { $wait = 5 } else { $wait = [Math]::Min($wait * 2, 300) }
    Start-Sleep -Seconds $wait
}
