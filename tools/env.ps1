# DeckOS dev environment for Windows (PowerShell 5.1+). Dot-source it:  . tools\env.ps1
#
# Puts the local toolchain (Qt 5.15.2 MinGW 8.1 + SDL2, see docs/DECISIONS.md) first on a
# minimal PATH. Git-bash's sh.exe must NOT be on PATH: qmake's win32-g++ makefiles assume
# cmd.exe and break when mingw32-make finds an sh.exe.
#
# Toolchain location: $env:DECKOS_TOOLCHAIN, else ..\toolchain next to the repo.

$ErrorActionPreference = 'Stop'

$script:DeckosRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tc = $env:DECKOS_TOOLCHAIN
if (-not $tc) { $tc = Join-Path $DeckosRoot '..\toolchain' }
if (-not (Test-Path $tc)) { throw "DeckOS toolchain not found at '$tc'. Set DECKOS_TOOLCHAIN or see docs/03-dev-loop.md." }
$script:Toolchain = (Resolve-Path $tc).Path

$script:QtDir    = Join-Path $Toolchain 'Qt\5.15.2\mingw81_64'
$script:MingwDir = Join-Path $Toolchain 'Qt\Tools\mingw810_64'
$script:SdlDir   = Join-Path $Toolchain 'SDL2-2.32.10\x86_64-w64-mingw32'
$script:BuildDir = Join-Path $DeckosRoot 'build'

foreach ($p in @($QtDir, $MingwDir, $SdlDir)) {
    if (-not (Test-Path $p)) { throw "Missing toolchain component: $p" }
}

# qmake calls git to stamp the version; keep git, but only its own directory.
$gitExe = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitExe) { throw 'git not found on PATH.' }
$gitDir = Split-Path $gitExe.Source
if (Test-Path (Join-Path $gitDir 'sh.exe')) {
    # Git\bin and Git\usr\bin ship sh.exe; Git\cmd has git.exe without it.
    $candidate = Join-Path $gitDir '..\cmd'
    if (-not (Test-Path (Join-Path $candidate 'git.exe'))) { $candidate = Join-Path $gitDir '..\..\cmd' }
    if (-not (Test-Path (Join-Path $candidate 'git.exe'))) { throw "git directory '$gitDir' contains sh.exe and no Git\cmd was found." }
    $gitDir = (Resolve-Path $candidate).Path
}

$env:PATH = "$QtDir\bin;$MingwDir\bin;$gitDir;$env:SystemRoot\System32;$env:SystemRoot;$env:SystemRoot\System32\WindowsPowerShell\v1.0"
