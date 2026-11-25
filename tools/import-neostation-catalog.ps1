# Converts NeoStation's system catalog (GPL-3.0, https://github.com/misobadev/neostation-frontend,
# assets/systems/*.json) into DeckOS's compact catalog: src/backend/deckos/catalog/systems.json.
# Usage:  tools\import-neostation-catalog.ps1 [-Source <neostation-frontend checkout>]
#
# Kept per system: id, name, short name, folder aliases, extensions, multi-disc flag, RetroAchievements
# console id. Kept per emulator: id, name, RetroArch/default flags, RA compatibility and the Android
# `am start` arguments, with NeoStation's placeholders mapped to Pegasus's:
#   {file.path} -> {file.path}      real path
#   {file.localuri}, {file.uri} -> {file.uri}   content:// URI DeckOS grants to the emulator
#   {file.dir} -> {file.dir}
# Emulators that need NeoStation-only data ({tags.*}, {file.content}) and store/meta systems are skipped.
param([string]$Source)
$ErrorActionPreference = 'Stop'

if (-not $Source) { $Source = Join-Path $PSScriptRoot '..\..\third_party_refs\neostation-frontend' }
$systemsDir = Join-Path $Source 'assets\systems'
if (-not (Test-Path $systemsDir)) { throw "NeoStation checkout not found: $systemsDir" }
$commit = (& git -C $Source rev-parse --short HEAD 2>$null)

# not ROM systems (stores, launchers, meta views)
$skipSystems = @('all', 'collections', 'favorites', 'android', 'android_games', 'steam', 'epic', 'gog', 'amazon', 'music')

$systems = @()
$emuCount = 0
foreach ($file in Get-ChildItem $systemsDir -Filter *.json | Sort-Object Name) {
    $json = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $sys = $json.system
    if (-not $sys -or $skipSystems -contains $sys.id) { continue }
    if (-not $sys.folders -or -not $sys.extensions) { continue }

    $emus = @()
    foreach ($emu in @($json.emulators)) {
        if (-not $emu.platforms -or -not $emu.platforms.android) { continue }
        $args = [string]$emu.platforms.android.launch_arguments
        if (-not $args) { continue }
        if ($args -match '\{tags\.|\{file\.content\}') { continue }
        $args = $args.Replace('{file.localuri}', '{file.uri}')   # NeoStation's uri forms -> Pegasus content URI
        $pkg = if ($args -match '-n\s+"?([\w.]+)/') { $Matches[1] } else { '' }
        $emus += [ordered]@{
            id = [string]$emu.unique_id
            name = [string]$emu.name
            package = $pkg
            isDefault = [bool]$emu.default_core
            retroArch = $pkg -like 'com.retroarch*'
            achievements = [bool]$emu.is_retroachievements_compatible
            args = $args
        }
    }
    $emuCount += $emus.Count

    $raId = 0
    if ($sys.ids -and $sys.ids.retroachievements) { $raId = [int]$sys.ids.retroachievements }
    $systems += [ordered]@{
        id = [string]$sys.id
        name = [string]$sys.name
        shortName = [string]$sys.short_name
        folders = @($sys.folders | ForEach-Object { [string]$_ })
        extensions = @($sys.extensions | ForEach-Object { ([string]$_).ToLower().TrimStart('.') })
        multidisc = [bool]$sys.multidisc
        raConsoleId = $raId
        emulators = $emus
    }
}

$out = [ordered]@{
    source = "NeoStation (GPL-3.0) https://github.com/misobadev/neostation-frontend assets/systems @ $commit, converted by tools/import-neostation-catalog.ps1"
    systems = $systems
}
$dest = Join-Path $PSScriptRoot '..\src\backend\deckos\catalog\systems.json'
New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
$text = $out | ConvertTo-Json -Depth 8 -Compress
[IO.File]::WriteAllText((Resolve-Path (Split-Path $dest)).Path + '\systems.json', $text, (New-Object Text.UTF8Encoding $false))
Write-Output ("[catalog] {0} systems, {1} Android emulators -> {2} ({3:N0} KB)" -f $systems.Count, $emuCount, $dest, ((Get-Item $dest).Length / 1KB))
