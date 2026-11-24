# Refreshes the double-clickable Windows test build in <DECKOS root>\windows-build\ (docs/03-dev-loop.md).
# tools\check.ps1 runs this as its last step, so the folder always holds the newest build that passed the gate.
# Usage:  tools\deploy-windows.ps1 [-OutDir <dir>]
#
# App files (exe, Qt/SDL/MinGW DLLs, plugins, QML modules, README.txt) are overwritten on every run.
# config\ and test-roms\ are created once and then left alone: settings, favorites and ROM folders
# added by hand survive rebuilds. Delete config\ to get the defaults back.
param([string]$OutDir)
. "$PSScriptRoot\env.ps1"

# UTF-8 without BOM (PowerShell 5.1's -Encoding utf8 adds one).
function Write-Utf8([string]$Path, [string[]]$Lines) { [IO.File]::WriteAllLines($Path, $Lines, (New-Object Text.UTF8Encoding $false)) }

if (-not $OutDir) { $OutDir = Join-Path $DeckosRoot '..\windows-build' }
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path

$exe = Get-ChildItem (Join-Path $BuildDir 'src\app\release') -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { Write-Output "[deploy] no build found - run tools\build.ps1 first"; exit 1 }

# The build target keeps upstream's name (pegasus-fe); the owner-facing copy is DeckOS.exe.
$appName = 'DeckOS.exe'
$running = Get-Process -Name ([IO.Path]::GetFileNameWithoutExtension($appName)), $exe.BaseName -ErrorAction SilentlyContinue |
    Where-Object { try { $_.Path -like "$OutDir\*" } catch { $false } }
if ($running) { Write-Output "[deploy] DeckOS is running from $OutDir - close it and run again"; exit 1 }

Copy-Item $exe.FullName (Join-Path $OutDir $appName) -Force
$old = Join-Path $OutDir $exe.Name                       # pre-rebrand copies were named pegasus-fe.exe
if (Test-Path -LiteralPath $old) { Remove-Item -LiteralPath $old -Force }
Copy-Item (Join-Path $SdlDir 'bin\SDL2.dll') $OutDir -Force
# HTTPS (RetroAchievements, artwork): Qt 5.15 needs OpenSSL 1.1.1 DLLs next to the exe. FireDaemon build,
# Authenticode-verified 2026-11-25 (docs/DECISIONS.md). Optional: without them the app runs, offline only.
$ssl = Join-Path $Toolchain 'openssl-1.1.1w'
if (Test-Path (Join-Path $ssl 'libssl-1_1-x64.dll')) {
    Copy-Item (Join-Path $ssl 'libssl-1_1-x64.dll'), (Join-Path $ssl 'libcrypto-1_1-x64.dll') $OutDir -Force
} else { Write-Output "[deploy] note: no OpenSSL 1.1.1 in $ssl - online features won't work on PC" }

# --debug is deliberate: aqt's MinGW Qt plugins carry a PE debug directory, so windeployqt classes them as
# debug builds and in release mode skips every one ("Unable to find the platform plugin"). Qt libraries are
# taken from the exe's import table, so they are the release DLLs either way. (docs/DECISIONS.md)
$log = Join-Path $BuildDir 'windeployqt.log'
$target = Join-Path $OutDir $appName
cmd /c "windeployqt --debug --compiler-runtime --no-translations --qmldir `"$DeckosRoot\src`" `"$target`" > `"$log`" 2>&1"
if ($LASTEXITCODE -ne 0) { Write-Output "[deploy] windeployqt failed (exit $LASTEXITCODE), see $log"; exit 1 }
if (-not (Test-Path (Join-Path $OutDir 'platforms\qwindows.dll'))) { Write-Output "[deploy] platform plugin missing after windeployqt, see $log"; exit 1 }

# Portable mode: settings live in .\config next to the exe instead of %LOCALAPPDATA%.
Write-Utf8 (Join-Path $OutDir 'portable.txt') @('Presence of this file keeps all settings in .\config')

# Fake library: 5-byte dummy files (never real ROMs) named after real games, so title-based
# RetroAchievements matching and artwork lookups behave like they do on a real library.
$roms = Join-Path $OutDir 'test-roms'
if (-not (Test-Path $roms)) {
    $systems = @(
        @{ dir = 'snes'; name = 'Super Nintendo'; ext = 'sfc, smc'; games = @(
            'Super Mario World (USA).sfc', 'Super Metroid (Japan, USA).sfc', 'Legend of Zelda, The - A Link to the Past (USA).sfc',
            'Donkey Kong Country (USA).sfc', 'Chrono Trigger (USA).sfc') },
        @{ dir = 'gba'; name = 'Game Boy Advance'; ext = 'gba'; games = @(
            'Metroid Fusion (USA).gba', 'Pokemon - Emerald Version (USA, Europe).gba', 'Mario Kart - Super Circuit (USA).gba',
            'Legend of Zelda, The - The Minish Cap (USA).gba') },
        @{ dir = 'nes'; name = 'Nintendo Entertainment System'; ext = 'nes'; games = @(
            'Super Mario Bros. 3 (USA).nes', 'Mega Man 2 (USA).nes', 'Legend of Zelda, The (USA).nes') },
        @{ dir = 'genesis'; name = 'Sega Genesis'; ext = 'md, gen'; games = @(
            'Sonic the Hedgehog (USA, Europe).md', 'Streets of Rage 2 (USA).md') }
    )
    foreach ($s in $systems) {
        $d = New-Item -ItemType Directory -Force (Join-Path $roms $s.dir)
        # Write-Utf8, not Set-Content: PS 5.1 mis-binds positional Set-Content args next to -Encoding.
        foreach ($g in $s.games) { Write-Utf8 (Join-Path $d.FullName $g) @('dummy') }
        # A harmless launch command: proves the launch path works; the line shows up in config\lastrun.log.
        Write-Utf8 (Join-Path $d.FullName 'metadata.pegasus.txt') @(
            "collection: $($s.name)",
            "shortname: $($s.dir)",
            "extensions: $($s.ext)",
            'launch: cmd /c echo launched {file.path}'
        )
    }
}

$config = Join-Path $OutDir 'config'
if (-not (Test-Path $config)) {
    New-Item -ItemType Directory -Force $config | Out-Null
    # game_dirs.txt is not recursive: one line per folder that directly holds a metadata.pegasus.txt.
    $dirs = Get-ChildItem $roms -Directory | ForEach-Object { $_.FullName }
    Write-Utf8 (Join-Path $config 'game_dirs.txt') $dirs
    # Windowed, and the PC-only importers off so the library matches what Android sees.
    Write-Utf8 (Join-Path $config 'settings.txt') @(
        'general.fullscreen: false',
        'providers.steam.enabled: false',
        'providers.gog.enabled: false',
        'providers.playnite.enabled: false',
        'providers.launchbox.enabled: false'
    )
}

$commit = (& git -C $DeckosRoot describe --always --dirty --match 'v[0-9]*' 2>$null)   # DeckOS tags only, not upstream's alphaN
Write-Utf8 (Join-Path $OutDir 'README.txt') @(
    'DeckOS - Windows test build',
    '',
    "Build:  $commit  ($(Get-Date -Format 'yyyy-MM-dd HH:mm'))",
    "Run:    double-click $appName",
    '',
    'This folder is refreshed automatically every time a build passes the test gate (tools\check.ps1).',
    'App files are replaced on each refresh; config\ and test-roms\ are kept.',
    '',
    'config\settings.txt   settings (windowed mode, PC-only importers off)',
    'config\game_dirs.txt  ROM folders to load, one per line (each must contain a metadata.pegasus.txt)',
    'config\lastrun.log    log of the last run - attach it to bug reports',
    'test-roms\            fake games for testing (dummy files, not real ROMs)',
    '',
    'Delete config\ to reset to defaults. Close the app before a rebuild, or the refresh fails.'
)

$size = (Get-ChildItem $OutDir -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Output ("[deploy] {0} -> {1} ({2:N0} MB)" -f $commit, $OutDir, $size)
exit 0
