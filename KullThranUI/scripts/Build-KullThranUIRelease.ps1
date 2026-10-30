param(
    [string]$OutputPath,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$mainAddonRoot = Split-Path $PSScriptRoot -Parent
$addonsRoot = Split-Path $mainAddonRoot -Parent
$addonFolders = @(
    "KullThranUI",
    "KullThranUI_ActionBars",
    "KullThranUI_Armory",
    "KullThranUI_AuraReminders",
    "KullThranUI_Bags",
    "KullThranUI_BuffsAndDebuffs",
    "KullThranUI_CastBar",
    "KullThranUI_Chat",
    "KullThranUI_CooldownManager",
    "KullThranUI_Cursor",
    "KullThranUI_DragonRiding",
    "KullThranUI_Enhancements",
    "KullThranUI_ExperienceBar",
    "KullThranUI_ExternalAddons",
    "KullThranUI_InspectArmory",
    "KullThranUI_Installer",
    "KullThranUI_Minimap",
    "KullThranUI_Nameplates",
    "KullThranUI_ObjectiveTracker",
    "KullThranUI_PartyFrames",
    "KullThranUI_ResourceBars",
    "KullThranUI_Skins",
    "KullThranUI_TeleportMenu",
    "KullThranUI_Tooltip",
    "KullThranUI_UnitFrames"
)

$mainToc = Join-Path $mainAddonRoot "KullThranUI.toc"
$mainTocContent = [System.IO.File]::ReadAllText($mainToc)
$interfaceMatch = [regex]::Match($mainTocContent, '(?m)^## Interface:\s*([0-9]+)')
$versionMatch = [regex]::Match($mainTocContent, '(?m)^## Version:\s*([^\r\n]+)')
if (-not $interfaceMatch.Success -or -not $versionMatch.Success) {
    throw "KullThranUI.toc must declare Interface and Version."
}
$currentInterface = $interfaceMatch.Groups[1].Value
$version = $versionMatch.Groups[1].Value.Trim()

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $addonsRoot ("KullThranUI-{0}.zip" -f $version)
}
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

$visitedXml = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

function Test-XmlReferences {
    param(
        [string]$XmlPath,
        [string]$AddonRoot
    )

    $fullXmlPath = [System.IO.Path]::GetFullPath($XmlPath)
    if (-not $visitedXml.Add($fullXmlPath)) {
        return
    }

    try {
        [xml]$document = [System.IO.File]::ReadAllText($fullXmlPath)
    } catch {
        throw "Invalid XML manifest '$fullXmlPath': $($_.Exception.Message)"
    }

    $nodes = $document.SelectNodes("//*[local-name()='Script' or local-name()='Include']")
    foreach ($node in $nodes) {
        $fileAttribute = $node.Attributes["file"]
        if (-not $fileAttribute) {
            continue
        }

        $referencedPath = [System.IO.Path]::GetFullPath(
            (Join-Path (Split-Path $fullXmlPath -Parent) ($fileAttribute.Value -replace '/', '\'))
        )
        $addonPrefix = [System.IO.Path]::GetFullPath($AddonRoot).TrimEnd('\') + '\'
        if (-not $referencedPath.StartsWith($addonPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "XML reference escapes addon root: $referencedPath"
        }
        if (-not (Test-Path -LiteralPath $referencedPath -PathType Leaf)) {
            throw "Missing XML reference: $referencedPath"
        }
        if ([System.IO.Path]::GetExtension($referencedPath) -ieq ".xml") {
            Test-XmlReferences -XmlPath $referencedPath -AddonRoot $AddonRoot
        }
    }
}

function Test-AddonManifest {
    param([string]$AddonName)

    $addonRoot = Join-Path $addonsRoot $AddonName
    $tocPath = Join-Path $addonRoot ($AddonName + ".toc")
    if (-not (Test-Path -LiteralPath $addonRoot -PathType Container)) {
        throw "Missing addon folder: $addonRoot"
    }
    if (-not (Test-Path -LiteralPath $tocPath -PathType Leaf)) {
        throw "Missing addon manifest: $tocPath"
    }

    $tocContent = [System.IO.File]::ReadAllText($tocPath)
    if ($tocContent -notmatch ('(?m)^## Interface:.*(?:^|[ ,])' + [regex]::Escape($currentInterface) + '(?:$|[ ,])')) {
        throw "$AddonName does not declare current Interface $currentInterface."
    }
    if ($AddonName -ne "KullThranUI" -and $tocContent -notmatch '(?m)^## Dependencies:\s*KullThranUI(?:\s|$)') {
        throw "$AddonName must depend on KullThranUI."
    }

    foreach ($line in [System.IO.File]::ReadAllLines($tocPath)) {
        $entry = $line.Trim()
        if ($entry.Length -eq 0 -or $entry.StartsWith("#")) {
            continue
        }

        $referencedPath = [System.IO.Path]::GetFullPath(
            (Join-Path $addonRoot ($entry -replace '/', '\'))
        )
        $addonPrefix = [System.IO.Path]::GetFullPath($addonRoot).TrimEnd('\') + '\'
        if (-not $referencedPath.StartsWith($addonPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "TOC reference escapes addon root: $referencedPath"
        }
        if (-not (Test-Path -LiteralPath $referencedPath -PathType Leaf)) {
            throw "Missing TOC reference: $referencedPath"
        }
        if ([System.IO.Path]::GetExtension($referencedPath) -ieq ".xml") {
            Test-XmlReferences -XmlPath $referencedPath -AddonRoot $addonRoot
        }
    }
}

foreach ($addonName in $addonFolders) {
    Test-AddonManifest -AddonName $addonName
}

$excludedDirectories = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
@(".git", ".github", ".agents", ".codex", ".codex-backups", ".vscode", "Backups", "node_modules") |
    ForEach-Object { [void]$excludedDirectories.Add($_) }
$excludedExtensions = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
@(".py", ".ps1", ".cmd", ".js", ".json", ".out") |
    ForEach-Object { [void]$excludedExtensions.Add($_) }
$excludedFileNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
@("original_view.txt", "KT_UnlockMode_Restored.lua", "Popups_restored.lua") |
    ForEach-Object { [void]$excludedFileNames.Add($_) }

function Copy-CleanDirectory {
    param(
        [string]$Source,
        [string]$Destination
    )

    [System.IO.Directory]::CreateDirectory($Destination) | Out-Null
    foreach ($item in Get-ChildItem -Force -LiteralPath $Source) {
        if ($item.PSIsContainer) {
            if ($excludedDirectories.Contains($item.Name)) {
                continue
            }
            Copy-CleanDirectory -Source $item.FullName -Destination (Join-Path $Destination $item.Name)
            continue
        }

        if ($item.Name.StartsWith(".") -or $excludedFileNames.Contains($item.Name) -or $excludedExtensions.Contains($item.Extension)) {
            continue
        }
        Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $Destination $item.Name)
    }
}

$stagingRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("KullThranUI-release-" + [guid]::NewGuid().ToString("N"))
$tempPrefix = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$stagingRoot = [System.IO.Path]::GetFullPath($stagingRoot)
if (-not $stagingRoot.StartsWith($tempPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Unsafe staging path: $stagingRoot"
}

try {
    [System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    foreach ($addonName in $addonFolders) {
        Copy-CleanDirectory `
            -Source (Join-Path $addonsRoot $addonName) `
            -Destination (Join-Path $stagingRoot $addonName)
    }

    if (Test-Path -LiteralPath $OutputPath) {
        if (-not $Force) {
            throw "Output already exists: $OutputPath. Use -Force to replace it."
        }
        Remove-Item -LiteralPath $OutputPath -Force
    }

    $outputDirectory = Split-Path $OutputPath -Parent
    [System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null
    Add-Type -AssemblyName System.IO.Compression
    $zipStream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::CreateNew)
    $archive = New-Object System.IO.Compression.ZipArchive(
        $zipStream,
        [System.IO.Compression.ZipArchiveMode]::Create,
        $false
    )
    try {
        foreach ($file in Get-ChildItem -LiteralPath $stagingRoot -Recurse -File) {
            $relativePath = $file.FullName.Substring($stagingRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $entry = $archive.CreateEntry($relativePath, [System.IO.Compression.CompressionLevel]::Optimal)
            $inputStream = $file.OpenRead()
            $outputStream = $entry.Open()
            try {
                $inputStream.CopyTo($outputStream)
            } finally {
                $outputStream.Dispose()
                $inputStream.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
        $zipStream.Dispose()
    }
} finally {
    if (Test-Path -LiteralPath $stagingRoot -PathType Container) {
        [System.IO.Directory]::Delete($stagingRoot, $true)
    }
}

Write-Output ("Created validated release: {0}" -f $OutputPath)
Write-Output ("Interface: {0}; Version: {1}; Addons: {2}" -f $currentInterface, $version, $addonFolders.Count)
