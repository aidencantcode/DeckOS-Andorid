# The Windows test gate (docs/13-release-flow.md). A build may only be shipped if this passes.
# Usage:  tools\check.ps1 [-Clean]
#
# Current steps: build → unit tests → refresh ..\windows-build (only reached if everything before passed).
# Added with the Phase 0 dev-tooling item: qmllint, offscreen smoke test, screenshot tour.
param([switch]$Clean)
$ErrorActionPreference = 'Stop'

function Invoke-Step([string]$Name, [scriptblock]$Body) {
    Write-Output "=== $Name"
    & $Body
    if ($LASTEXITCODE -ne 0) { Write-Output "=== GATE FAILED at: $Name"; exit 1 }
}

$started = Get-Date
$buildArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\build.ps1")
if ($Clean) { $buildArgs += '-Clean' }   # switches can't be passed as -Clean:$false through -File
Invoke-Step 'build' { & powershell @buildArgs }
Invoke-Step 'unit tests' { & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\test.ps1" }
Invoke-Step 'windows-build' { & powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\deploy-windows.ps1" }

Write-Output ("=== GATE PASSED in {0}s" -f [int]((Get-Date) - $started).TotalSeconds)
exit 0
