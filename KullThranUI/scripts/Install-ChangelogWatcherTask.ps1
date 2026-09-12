<#
Registra una tarea programada de usuario para arrancar el watcher del changelog
en cada inicio de sesion.

Uso:
  powershell -ExecutionPolicy Bypass -File .\scripts\Install-ChangelogWatcherTask.ps1
#>

param(
    [string]$TaskName = "KullThranUI-ChangelogWatcher",
    [string]$AddonRoot = (Split-Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Import-Module ScheduledTasks -ErrorAction Stop

$watchScript = Join-Path $PSScriptRoot "Watch-Changelog.ps1"
if (-not (Test-Path $watchScript)) {
    throw "No existe Watch-Changelog.ps1 en $watchScript"
}

$psExe = (Get-Command powershell.exe).Source
$taskArgs = ('-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $watchScript)

$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "La tarea ya existe. Se actualizara: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$action = New-ScheduledTaskAction -Execute $psExe -Argument $taskArgs
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings | Out-Null

Write-Host "OK: tarea registrada -> $TaskName"
Write-Host ("Accion: {0} {1}" -f $psExe, $taskArgs)
