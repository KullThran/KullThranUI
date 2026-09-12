<#
Uso recomendado (desde KullThranUI):
  powershell -ExecutionPolicy Bypass -File .\scripts\Sync-Changelog.ps1

Que hace:
1) Actualiza los bloques AUTO-CHANGELOG de Options.lua desde Wago (si hay red).
2) Genera CHANGELOG.md en la raiz del addon para publicacion en Curse/Wago.
#>

param(
    [string]$AddonRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OptionsPath,
    [string]$TocPath,
    [string]$ChangelogPath,
    [string]$AddonSlug = "kullthranui",
    [switch]$SkipWagoSync
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $OptionsPath) {
    $OptionsPath = Join-Path $AddonRoot "Options.lua"
}
if (-not $TocPath) {
    $TocPath = Join-Path $AddonRoot "KullThranUI.toc"
}
if (-not $ChangelogPath) {
    $ChangelogPath = Join-Path $AddonRoot "CHANGELOG.md"
}

if (-not (Test-Path $OptionsPath)) { throw "No existe Options.lua: $OptionsPath" }
if (-not (Test-Path $TocPath)) { throw "No existe TOC: $TocPath" }

function Get-TocVersion {
    param([string]$Path)
    $line = Get-Content $Path | Where-Object { $_ -match '^##\s*Version\s*:\s*(.+)$' } | Select-Object -First 1
    if (-not $line) { return $null }
    return ([regex]::Match($line, '^##\s*Version\s*:\s*(.+)$').Groups[1].Value).Trim()
}

function Try-RunWagoSync {
    param(
        [string]$ScriptPath,
        [string]$Slug,
        [string]$TargetOptions
    )

    if (-not (Test-Path $ScriptPath)) {
        Write-Warning "No existe script Wago: $ScriptPath"
        return
    }

    try {
        & $ScriptPath -AddonSlug $Slug -OptionsPath $TargetOptions
    }
    catch {
        Write-Warning ("No se pudo actualizar desde Wago: {0}" -f $_.Exception.Message)
        Write-Warning "Se continuara con los datos locales de Options.lua"
    }
}

function Parse-EntriesFromOptions {
    param([string]$Content)

    $entries = New-Object System.Collections.Generic.List[object]
    $entryPattern = '(?s)\["(?<version>[^"]+)"\]\s*=\s*\{\s*version\s*=\s*"[^"]+"\s*,\s*published\s*=\s*"(?<published>[^"]*)"\s*,.*?notes\s*=\s*\{(?<notes>.*?)\}\s*,\s*\}\s*,'
    $matches = [regex]::Matches($Content, $entryPattern)

    foreach ($m in $matches) {
        $version = $m.Groups['version'].Value
        $published = $m.Groups['published'].Value
        $notesRaw = $m.Groups['notes'].Value
        $notes = New-Object System.Collections.Generic.List[string]

        foreach ($noteMatch in [regex]::Matches($notesRaw, '"(?<txt>(?:\\.|[^"])*)"\s*,')) {
            $note = $noteMatch.Groups['txt'].Value
            $note = $note -replace '\\"', '"'
            $note = $note -replace '\\\\', '\\'
            $note = $note.Trim()
            if ($note) {
                $notes.Add($note)
            }
        }

        $entries.Add([PSCustomObject]@{
            version = $version
            published = $published
            notes = $notes
        })
    }

    return $entries
}

function Get-VersionSortKey {
    param([string]$VersionText)

    $parts = @()
    foreach ($token in ([regex]::Matches(($VersionText -as [string]), '(\d+)') | ForEach-Object { $_.Groups[1].Value })) {
        $parts += [int]$token
    }

    while ($parts.Count -lt 4) {
        $parts += 0
    }

    return ('{0:D4}.{1:D4}.{2:D4}.{3:D4}' -f $parts[0], $parts[1], $parts[2], $parts[3])
}

function Build-Markdown {
    param(
        [string]$CurrentVersion,
        [System.Collections.Generic.List[object]]$Entries,
        [string]$WagoUrl,
        [string]$CurseUrl
    )

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# KullThranUI Changelog")
    [void]$sb.AppendLine("")
    if ($CurrentVersion) {
        [void]$sb.AppendLine(("Current addon version: **{0}**" -f $CurrentVersion))
        [void]$sb.AppendLine("")
    }
    [void]$sb.AppendLine(("Primary source: {0}" -f $WagoUrl))
    [void]$sb.AppendLine(("Secondary source: {0}" -f $CurseUrl))
    [void]$sb.AppendLine("")

    foreach ($entry in $Entries) {
        [void]$sb.AppendLine(("## {0} ({1})" -f $entry.version, $entry.published))
        if ($entry.notes.Count -gt 0) {
            foreach ($note in $entry.notes) {
                [void]$sb.AppendLine(("- {0}" -f $note))
            }
        }
        else {
            [void]$sb.AppendLine("- No notes available.")
        }
        [void]$sb.AppendLine("")
    }

    return $sb.ToString().TrimEnd() + "`r`n"
}

if (-not $SkipWagoSync) {
    $wagoScript = Join-Path $PSScriptRoot "Update-ChangelogFromWago.ps1"
    Try-RunWagoSync -ScriptPath $wagoScript -Slug $AddonSlug -TargetOptions $OptionsPath
}

$tocVersion = Get-TocVersion -Path $TocPath
$optionsContent = Get-Content $OptionsPath -Raw

$wagoUrl = "https://addons.wago.io/addons/$AddonSlug/versions"
$curseUrl = "https://www.curseforge.com/wow/addons/kui-kullthranui/files"

if ($optionsContent -match 'local\s+CHANGELOG_WAGO_URL\s*=\s*"([^"]+)"') {
    $wagoUrl = $Matches[1]
}
if ($optionsContent -match 'local\s+CHANGELOG_FILES_URL\s*=\s*"([^"]+)"') {
    $curseUrl = $Matches[1]
}

$entries = Parse-EntriesFromOptions -Content $optionsContent
if ($entries.Count -eq 0) {
    throw "No se pudieron parsear entradas de changelog desde Options.lua"
}

$sorted = $entries | Sort-Object -Property @{ Expression = { Get-VersionSortKey -VersionText $_.version }; Descending = $true }

$md = Build-Markdown -CurrentVersion $tocVersion -Entries $sorted -WagoUrl $wagoUrl -CurseUrl $curseUrl
[System.IO.File]::WriteAllText($ChangelogPath, $md, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "OK: CHANGELOG.md generado en $ChangelogPath"
Write-Host ("Entradas exportadas: {0}" -f $sorted.Count)
if ($tocVersion) {
    $hasCurrent = $sorted | Where-Object { $_.version -eq $tocVersion } | Select-Object -First 1
    if ($hasCurrent) {
        Write-Host ("Version actual {0}: presente en changelog" -f $tocVersion)
    }
    else {
        Write-Warning ("Version actual {0}: NO encontrada en changelog archivado" -f $tocVersion)
    }
}