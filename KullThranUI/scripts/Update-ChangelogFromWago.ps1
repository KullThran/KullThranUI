<#
Uso:
  powershell -ExecutionPolicy Bypass -File .\scripts\Update-ChangelogFromWago.ps1
#>

param(
    [string]$AddonSlug = "kullthranui",
    [string]$OptionsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Options.lua")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-WagoInertiaJson {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $html = (Invoke-WebRequest -UseBasicParsing $Url).Content
    $match = [regex]::Match($html, 'data-page="([^"]+)"')
    if (-not $match.Success) {
        throw "No se pudo localizar el atributo data-page en $Url"
    }

    $decoded = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value)
    return $decoded | ConvertFrom-Json
}

function Get-VersionFromLabel {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $match = [regex]::Match($Label, '(\d+\.\d+\.\d+)')
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function Convert-WagoChangelogToNotes {
    param(
        [AllowNull()]
        [string]$Changelog
    )

    $notes = New-Object System.Collections.Generic.List[string]
    if ([string]::IsNullOrWhiteSpace($Changelog)) {
        return $notes
    }

    foreach ($rawLine in ($Changelog -split "`r?`n")) {
        $line = $rawLine.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        # Limpia markdown frecuente en notas de Wago
        $line = $line -replace '^#+\s*', ''
        $line = $line -replace '^\*\*(.+)\*\*$', '$1'
        $line = $line -replace '\*\*', ''
        $line = $line.Trim(' *-`')

        # Descarta lineas que solo son una version/encabezado
        if ($line -match '^v?\d+\.\d+\.\d+$') {
            continue
        }

        # Descarta encabezados de version con fecha: "5.0.6 (2026-09-12)"
        if ($line -match '^v?\d+\.\d+\.\d+\s*\(\d{4}-\d{2}-\d{2}\)$') {
            continue
        }

        # Descarta metadata que Wago incluye en el changelog
        if ($line -match '^KullThranUI Changelog$') { continue }
        if ($line -match '^Current addon version:') { continue }
        if ($line -match '^Primary source:') { continue }
        if ($line -match '^Secondary source:') { continue }

        $line = $line -replace '^\-\s*', ''
        $line = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        $notes.Add($line)
    }

    return $notes
}

function ConvertTo-LuaString {
    param(
        [AllowNull()]
        [string]$Value
    )

    if ($null -eq $Value) {
        return '""'
    }

    $escaped = $Value.Replace('\', '\\').Replace('"', '\"')
    return '"' + $escaped + '"'
}

function Get-LuaChangelogBlock {
    param(
        [Parameter(Mandatory = $true)]
        [array]$Entries
    )

    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine('-- AUTO-CHANGELOG:BEGIN')
    [void]$builder.AppendLine('local CHANGELOG_ENTRIES = {')

    foreach ($entry in $Entries) {
        [void]$builder.AppendLine(("    [{0}] = {{" -f (ConvertTo-LuaString $entry.version)))
        [void]$builder.AppendLine(("        version = {0}," -f (ConvertTo-LuaString $entry.version)))
        [void]$builder.AppendLine(("        published = {0}," -f (ConvertTo-LuaString $entry.published)))
        [void]$builder.AppendLine('        sourceLabel = "Wago Addons",')
        [void]$builder.AppendLine('        sourceUrl = CHANGELOG_WAGO_URL,')
        [void]$builder.AppendLine('        notes = {')

        foreach ($note in $entry.notes) {
            [void]$builder.AppendLine(("            {0}," -f (ConvertTo-LuaString $note)))
        }

        [void]$builder.AppendLine('        },')
        [void]$builder.AppendLine('    },')
    }

    [void]$builder.AppendLine('}')
    [void]$builder.Append('-- AUTO-CHANGELOG:END')
    return $builder.ToString()
}

function Get-LuaLatestVersionBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Version
    )

    return @"
-- AUTO-CHANGELOG-LATEST:BEGIN
local CHANGELOG_LATEST_ARCHIVED_VERSION = "$Version"
-- AUTO-CHANGELOG-LATEST:END
"@.TrimEnd()
}

$versionsUrl = "https://addons.wago.io/addons/$AddonSlug/versions?stability=stable&page=1"
$collected = @{}
$nextPageUrl = $versionsUrl

while ($nextPageUrl) {
    $pageData = Get-WagoInertiaJson -Url $nextPageUrl
    $releases = $pageData.props.releases

    foreach ($release in $releases.data) {
        if ($release.stability -ne "stable") {
            continue
        }

        $version = Get-VersionFromLabel -Label $release.label
        if (-not $version) {
            continue
        }

        if (-not $collected.ContainsKey($version)) {
            $published = ([DateTimeOffset]::Parse($release.created_at)).ToString("yyyy-MM-dd")
            $collected[$version] = [PSCustomObject]@{
                version = $version
                published = $published
                notes = Convert-WagoChangelogToNotes -Changelog $release.changelog
            }
        }
    }

    $nextPageUrl = $releases.next_page_url
}

if ($collected.Count -eq 0) {
    throw "Wago no devolvio versiones estables para $AddonSlug"
}

$sortedEntries = $collected.Values |
    Sort-Object -Property @{ Expression = { [version]$_.version }; Descending = $true }

$latestVersion = $sortedEntries[0].version

$optionsContent = Get-Content $OptionsPath -Raw
$updatedContent = [regex]::Replace(
    $optionsContent,
    '(?s)-- AUTO-CHANGELOG-LATEST:BEGIN.*?-- AUTO-CHANGELOG-LATEST:END',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) Get-LuaLatestVersionBlock -Version $latestVersion }
)

$updatedContent = [regex]::Replace(
    $updatedContent,
    '(?s)-- AUTO-CHANGELOG:BEGIN.*?-- AUTO-CHANGELOG:END',
    [System.Text.RegularExpressions.MatchEvaluator]{ param($m) Get-LuaChangelogBlock -Entries $sortedEntries }
)

[System.IO.File]::WriteAllText($OptionsPath, $updatedContent, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Changelog actualizado desde Wago en $OptionsPath"
Write-Host ("Version mas reciente: {0}" -f $latestVersion)
Write-Host "Versiones incluidas:"
$sortedEntries | ForEach-Object {
    Write-Host (" - {0} ({1})" -f $_.version, $_.published)
}
