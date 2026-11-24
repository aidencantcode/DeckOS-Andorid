# Ships a DeckOS test build (docs/13-release-flow.md):
#   checks -> CHANGELOG "## Unreleased" becomes "## <version> - <date>" -> commit + tag v<version> locally
#   -> the gate (tools\check.ps1 -Clean) on exactly that commit -> push main + tag -> GitHub builds the APK
#   and publishes the pre-release. If the gate fails, the commit and tag are undone and nothing is pushed.
# Usage:  tools\ship.ps1 [-Phase N] [-DryRun] [-Trailer "Co-Authored-By: ..."]
#   -Phase   roadmap phase of this build; defaults to the phase of the last tag (0 before the first one).
#            A new phase restarts the build number: 0.0.7 -> (-Phase 1) -> 0.1.1.
#   -DryRun  print the version and release notes, change nothing.
param([int]$Phase = -1, [switch]$DryRun, [string]$Trailer)
. "$PSScriptRoot\env.ps1"
# git writes progress and "no tags yet" to stderr, which Windows PowerShell 5.1 turns into terminating
# errors under 'Stop'. Every git call below is checked through its exit code instead.
$ErrorActionPreference = 'Continue'
Set-Location $DeckosRoot

function Stop-Ship([string]$Msg) { Write-Output "[ship] $Msg"; exit 1 }
function Invoke-Git {
    & git @args 2>&1 | ForEach-Object { "    $_" }
    if ($LASTEXITCODE -ne 0) { Stop-Ship "git $($args -join ' ') failed" }
}
$Utf8 = New-Object Text.UTF8Encoding $false
$Dash = [char]0x2014   # em dash, kept out of the source so Windows PowerShell 5.1 parses this file

# --- preconditions --------------------------------------------------------------------------------
if ((git rev-parse --abbrev-ref HEAD) -ne 'main') { Stop-Ship 'not on branch main' }
if (git status --porcelain) { Stop-Ship 'working tree not clean - commit or stash first' }
Invoke-Git fetch --quiet origin main
if ((git rev-list --count HEAD..origin/main) -ne '0') { Stop-Ship 'origin/main has commits this branch lacks - pull first' }

$changelogPath = Join-Path $DeckosRoot 'CHANGELOG.md'
$changelog = [IO.File]::ReadAllText($changelogPath, $Utf8)
$nl = if ($changelog.Contains("`r`n")) { "`r`n" } else { "`n" }
$m = [regex]::Match($changelog, '(?ms)^## Unreleased[ \t]*\r?\n(.*?)(?=^## |\z)')
if (-not $m.Success) { Stop-Ship 'CHANGELOG.md has no "## Unreleased" section' }
$notes = $m.Groups[1].Value.Trim()
if (-not $notes) { Stop-Ship 'the "## Unreleased" section of CHANGELOG.md is empty - write what changed first' }

# --- version ---------------------------------------------------------------------------------------
$last = git describe --tags --abbrev=0 --match 'v[0-9]*' 2>$null
if ($LASTEXITCODE -ne 0 -or -not $last) { $last = 'v0.0.0' }
$lm = [regex]::Match($last, '^v(\d+)\.(\d+)\.(\d+)$')
if (-not $lm.Success) { Stop-Ship "can't parse last tag '$last'" }
$major = [int]$lm.Groups[1].Value; $lastPhase = [int]$lm.Groups[2].Value; $lastBuild = [int]$lm.Groups[3].Value
if ($Phase -lt 0) { $Phase = $lastPhase }
if ($Phase -lt $lastPhase) { Stop-Ship "phase $Phase is older than the last release $last" }
$build = if ($Phase -eq $lastPhase) { $lastBuild + 1 } else { 1 }
if ($build -gt 999) { Stop-Ship 'build number above 999 - versionCode would overflow into the next phase' }
$version = "$major.$Phase.$build"
$tag = "v$version"
if (git tag -l $tag) { Stop-Ship "tag $tag already exists" }
$date = Get-Date -Format 'yyyy-MM-dd'

Write-Output "[ship] last release: $last  ->  this build: $version ($tag), versionCode $($major * 1000000 + $Phase * 1000 + $build)"
Write-Output "[ship] release notes:"
$notes -split "\r?\n" | ForEach-Object { Write-Output "    $_" }
if ($DryRun) { Write-Output '[ship] dry run - nothing changed'; exit 0 }

# --- commit + tag locally ----------------------------------------------------------------------------
# "## Unreleased" stays on top (empty) for the next build's notes; this build gets its own heading.
$hm = [regex]::Match($changelog, '(?m)^## Unreleased[ \t]*(?=\r?\n)')
$heading = "## Unreleased$nl$nl## $version $Dash $date"
$updated = $changelog.Substring(0, $hm.Index) + $heading + $changelog.Substring($hm.Index + $hm.Length)
[IO.File]::WriteAllText($changelogPath, $updated, $Utf8)
Invoke-Git add CHANGELOG.md
$message = "Release DeckOS $version"
if ($Trailer) { $message += "`n`n$Trailer" }
$msgFile = Join-Path $BuildDir 'ship-commit-msg.txt'
New-Item -ItemType Directory -Force $BuildDir | Out-Null
[IO.File]::WriteAllText($msgFile, $message + "`n", $Utf8)
Invoke-Git commit --quiet -F $msgFile
Invoke-Git tag -a $tag -m "DeckOS $version"

# --- the gate, on exactly the release commit ---------------------------------------------------------
& powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\check.ps1" -Clean
if ($LASTEXITCODE -ne 0) {
    git tag -d $tag 2>&1 | Out-Null
    git reset --quiet --keep HEAD~1 2>&1 | Out-Null
    Stop-Ship "gate failed - release commit and tag $tag undone, nothing pushed"
}

# --- publish -----------------------------------------------------------------------------------------
Invoke-Git push --atomic origin main $tag
$repo = (git remote get-url origin) -replace '\.git$', ''
Write-Output "[ship] pushed $tag. GitHub is building the APK (about 5 minutes):"
Write-Output "         $repo/actions/workflows/android.yml"
Write-Output "       then it appears on $repo/releases/tag/$tag"
exit 0
