<#
Instala autoarranque del watcher en la carpeta Inicio del usuario actual.
No requiere privilegios de administrador.
#>

param(
    [string]$AddonRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$StartupEntryName = "KullThranUI-ChangelogWatcher.vbs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$watchScript = Join-Path $PSScriptRoot "Watch-Changelog.ps1"
if (-not (Test-Path $watchScript)) {
    throw "No existe Watch-Changelog.ps1 en $watchScript"
}

$startupDir = [Environment]::GetFolderPath("Startup")
if (-not (Test-Path $startupDir)) {
    throw "No existe la carpeta Startup del usuario: $startupDir"
}

$legacyStartupEntryPath = Join-Path $startupDir "KullThranUI-ChangelogWatcher.cmd"
$startupEntryPath = Join-Path $startupDir $StartupEntryName
$escapedWatchScript = $watchScript.Replace('"', '""')
$vbs = @"
Set shell = CreateObject("WScript.Shell")
shell.Run "powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File ""$escapedWatchScript""", 0, False
"@

if (Test-Path $legacyStartupEntryPath) {
    Remove-Item -Path $legacyStartupEntryPath -Force
}

[System.IO.File]::WriteAllText($startupEntryPath, $vbs, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "OK: autoarranque instalado en Startup"
Write-Host $startupEntryPath
