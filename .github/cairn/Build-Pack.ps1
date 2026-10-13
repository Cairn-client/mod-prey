# Copyright (C) 2026 the Cairn contributors. SPDX-License-Identifier: GPL-3.0-only (as the project it is part of)
<#
.SYNOPSIS
    Builds the Cairn mod pack for Prey (CoopPrototype, a Chairloader mod): release\Cairn-Pack-prey-<version>.zip and release\pack-index.json
    (what the Cairn launcher reads to see a newer pack exists).

.DESCRIPTION
    An *external* pack that goes into the game's Mods\CoopPrototype folder (docs in the launcher repository: docs/PACKS.md): a Chairloader mod is a
    folder with its ModInfo.xml and its DLL.

      mod\CoopPrototype.dll   the mod, as this repository builds it
      mod\ModInfo.xml         the mod's description for Chairloader
      pack.json, manifest.txt

    NOT in the pack: Chairloader itself. It patches the game and has its own manager, so the player installs it first (Chairloader 1.3.4, the
    revision this mod is built against, is the one the project supports).

    The pack's version is the VERSION file (strict X.Y.Z, this project's own); the mod's version (ModInfo.xml) is the pack's "upstream".
    A file of the game's with the same name and other bytes is never overwritten by the launcher.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string] $Dll
)

$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$version = (Get-Content (Join-Path $root 'VERSION') -TotalCount 1).Trim()
if ($version -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') { throw "VERSION must be strict X.Y.Z, got '$version'" }
$infoPath = Join-Path $root 'CoopPrototype\ModInfo.xml'
$upstream = [regex]::Match((Get-Content $infoPath -Raw), 'version="(\d+\.\d+\.\d+)"').Groups[1].Value
if (-not $upstream) { throw 'could not read the mod version from CoopPrototype\ModInfo.xml' }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$release = Join-Path $root 'release'
$stage = Join-Path $release 'pack-stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
$mod = Join-Path $stage 'mod'
New-Item -ItemType Directory -Force -Path $mod | Out-Null
Copy-Item $Dll (Join-Path $mod 'CoopPrototype.dll')
Copy-Item $infoPath (Join-Path $mod 'ModInfo.xml')
Copy-Item (Join-Path $root 'LICENSE') (Join-Path $mod 'LICENSE')

function Get-Sha256([string] $Path) { (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant() }

$launcherMin = '0.3.22'
$packJson = [ordered]@{
    schema      = 2
    id          = 'prey'
    game        = 'prey'
    version     = $version
    upstream    = $upstream
    kind        = 'external'
    installDir  = 'Mods/CoopPrototype'
    launcherMin = $launcherMin
}
[IO.File]::WriteAllText((Join-Path $stage 'pack.json'), (($packJson | ConvertTo-Json) + "`n"), (New-Object System.Text.UTF8Encoding($false)))

$lines = New-Object System.Collections.Generic.List[string]
foreach ($f in Get-ChildItem $mod -Recurse -File | Sort-Object FullName) {
    $rel = $f.FullName.Substring($mod.Length + 1)
    $lines.Add(('MOD|{0}|{1}|{2}' -f $rel, $f.Length, (Get-Sha256 $f.FullName)))
}
[IO.File]::WriteAllText((Join-Path $stage 'manifest.txt'), (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))

$zipName = "Cairn-Pack-prey-$version.zip"
$zipPath = Join-Path $release $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$fs = [IO.File]::Open($zipPath, 'Create')
try {
    $z = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($f in Get-ChildItem $stage -Recurse -File) {
            $rel = $f.FullName.Substring($stage.Length + 1) -replace '\\', '/'
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($z, $f.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $z.Dispose() }
} finally { $fs.Dispose() }

$index = [ordered]@{
    schema      = 2
    id          = 'prey'
    game        = 'prey'
    version     = $version
    upstream    = $upstream
    kind        = 'external'
    file        = $zipName
    sha256      = Get-Sha256 $zipPath
    size        = (Get-Item $zipPath).Length
    launcherMin = $launcherMin
}
[IO.File]::WriteAllText((Join-Path $release 'pack-index.json'), (($index | ConvertTo-Json) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Host "pack: $zipPath ($([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB), version $version, CoopPrototype $upstream, $($lines.Count) files"
