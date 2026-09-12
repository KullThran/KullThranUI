<#
Auto watcher local para changelog.

Uso:
  powershell -ExecutionPolicy Bypass -File .\scripts\Watch-Changelog.ps1

Funcionamiento:
- Vigila cambios en KullThranUI.toc (linea ## Version).
- Cuando detecta cambio, ejecuta Sync-Changelog.ps1 automaticamente.
- Tambien hace una sincronizacion inicial al arrancar.
#>

param(
    [string]$AddonRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$RunOnce
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$tocPath = Join-Path $AddonRoot "KullThranUI.toc"
$syncScript = Join-Path $PSScriptRoot "Sync-Changelog.ps1"

if (-not (Test-Path $tocPath)) {
    throw "No existe TOC principal: $tocPath"
}
if (-not (Test-Path $syncScript)) {
    throw "No existe script de sync: $syncScript"
}

function Invoke-Sync {
    param([string]$Reason)

    Write-Host ("[{0}] Sync changelog: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Reason)
    try {
        & $syncScript
        Write-Host "Sync completado."
    }
    catch {
        Write-Warning ("Fallo en sync: {0}" -f $_.Exception.Message)
    }
}

function Get-VersionLine {
    param([string]$Path)

    $line = Get-Content $Path | Where-Object { $_ -match '^##\s*Version\s*:' } | Select-Object -First 1
    return ($line -as [string])
}

$script:lastVersionLine = Get-VersionLine -Path $tocPath

Invoke-Sync -Reason "arranque"

if ($RunOnce) {
    Write-Host "RunOnce completado."
    exit 0
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = (Split-Path $tocPath -Parent)
$watcher.Filter = (Split-Path $tocPath -Leaf)
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]'LastWrite, Size'
$watcher.EnableRaisingEvents = $true

$onChange = {
    Start-Sleep -Milliseconds 250

    $current = Get-VersionLine -Path $using:tocPath
    if ($null -eq $current) {
        return
    }

    if ($current -ne $script:lastVersionLine) {
        $previous = $script:lastVersionLine
        $script:lastVersionLine = $current
        Invoke-Sync -Reason ("version change: '{0}' -> '{1}'" -f $previous, $current)
    }
}

$createdReg = Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange

Write-Host "Watch-Changelog activo. Pulsa Ctrl+C para detener."
try {
    while ($true) {
        Wait-Event -Timeout 1 | Out-Null
    }
}
finally {
    Unregister-Event -SourceIdentifier $createdReg.Name -ErrorAction SilentlyContinue
    $watcher.Dispose()
}
