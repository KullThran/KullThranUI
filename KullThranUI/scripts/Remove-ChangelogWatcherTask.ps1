<#
Elimina la tarea programada del watcher del changelog.

Uso:
  powershell -ExecutionPolicy Bypass -File .\scripts\Remove-ChangelogWatcherTask.ps1
#>

param(
    [string]$TaskName = "KullThranUI-ChangelogWatcher"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ScheduledTasks -ErrorAction Stop

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $existing) {
    Write-Host "La tarea no existe: $TaskName"
    exit 0
}

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false

Write-Host "OK: tarea eliminada -> $TaskName"
