<#
Elimina el autoarranque del watcher desde la carpeta Inicio del usuario actual.
#>

param(
    [string]$StartupEntryName = "KullThranUI-ChangelogWatcher.vbs"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$startupDir = [Environment]::GetFolderPath("Startup")
$startupEntryPath = Join-Path $startupDir $StartupEntryName
$legacyStartupEntryPath = Join-Path $startupDir "KullThranUI-ChangelogWatcher.cmd"
$removedPaths = @()

if (Test-Path $startupEntryPath) {
    Remove-Item -Path $startupEntryPath -Force
    $removedPaths += $startupEntryPath
}

if (Test-Path $legacyStartupEntryPath) {
    Remove-Item -Path $legacyStartupEntryPath -Force
    $removedPaths += $legacyStartupEntryPath
}

if ($removedPaths.Count -gt 0) {
    Write-Host "OK: autoarranque eliminado"
    $removedPaths | ForEach-Object { Write-Host $_ }
}
else {
    Write-Host "No existe entrada en Startup"
    Write-Host $startupEntryPath
}
