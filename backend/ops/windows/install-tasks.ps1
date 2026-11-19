<#
.SYNOPSIS
    Registers the Reading Racoon background services to start with Windows (D-036).

.DESCRIPTION
    Creates two Scheduled Tasks that start at boot, whether or not anyone is
    signed in, run as SYSTEM, and restart if they stop:
      ReadingRacoon-Queue      php artisan queue:work (server replay, Gemini reports)
      ReadingRacoon-Scheduler  php artisan schedule:work (02:30 backup, pruning, heartbeat)
    Apache, PostgreSQL and cloudflared run as their own Windows services.

    Run once from an ADMINISTRATOR PowerShell. Read it first; it changes
    nothing else. Remove with: -Uninstall

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File install-tasks.ps1
#>
param(
    [string]$Php = "C:\xampp\php\php.exe",
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$runner = Join-Path $PSScriptRoot "run-forever.ps1"
$tasks = @{
    "ReadingRacoon-Queue"     = "queue:work --tries=5 --max-time=3600 --sleep=3"
    "ReadingRacoon-Scheduler" = "schedule:work"
}

foreach ($task in $tasks.GetEnumerator()) {
    if (Get-ScheduledTask -TaskName $task.Key -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $task.Key -Confirm:$false
    }
    if ($Uninstall) { Write-Host "Removed $($task.Key)"; continue }

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument (
        "-NoProfile -ExecutionPolicy Bypass -File `"$runner`" -Command `"$($task.Value)`" -Php `"$Php`"")
    $trigger = New-ScheduledTaskTrigger -AtStartup
    # Never stopped for running long, restarted if the runner itself dies, and
    # kept running on battery (a laptop on battery during a power cut is the point).
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) `
        -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
        -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    Register-ScheduledTask -TaskName $task.Key -Action $action -Trigger $trigger -Settings $settings `
        -Principal $principal -Description "Reading Racoon: php artisan $($task.Value)" | Out-Null
    Start-ScheduledTask -TaskName $task.Key
    Write-Host "Registered and started $($task.Key)"
}
