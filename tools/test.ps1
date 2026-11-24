# Run all Qt Test unit tests from an existing build. Usage:  tools\test.ps1
# Each suite writes to build\test-results\<suite>.txt — on Windows, QTest output does not
# reliably reach a redirected stdout, so `make check` logs can't be trusted for results.
. "$PSScriptRoot\env.ps1"
$env:PATH = "$SdlDir\bin;$env:PATH"

$out = Join-Path $BuildDir 'test-results'
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
New-Item -ItemType Directory -Force $out | Out-Null

$suites = Get-ChildItem (Join-Path $BuildDir 'tests') -Recurse -Filter 'test_*.exe' |
    Where-Object { $_.Directory.Name -eq 'release' }
if (-not $suites) { throw 'No test executables found — run tools\build.ps1 first.' }

$passed = 0; $failed = 0; $skipped = 0; $problems = @()
foreach ($exe in $suites) {
    $result = Join-Path $out "$($exe.BaseName).txt"
    Push-Location $exe.Directory.Parent.FullName
    & $exe.FullName -o "$result,txt" | Out-Null
    $code = $LASTEXITCODE
    Pop-Location
    $totals = (Select-String -Path $result -Pattern '^Totals:' -ErrorAction SilentlyContinue).Line
    if ($totals -match 'Totals: (\d+) passed, (\d+) failed, (\d+) skipped') {
        $passed += [int]$Matches[1]; $failed += [int]$Matches[2]; $skipped += [int]$Matches[3]
    }
    if ($code -ne 0 -or -not $totals) {
        $problems += "$($exe.BaseName) (exit $code)"
        Select-String -Path $result -Pattern '^FAIL!' -Context 0,2 -ErrorAction SilentlyContinue |
            ForEach-Object { Write-Output "  $($_.Line)"; $_.Context.PostContext | ForEach-Object { Write-Output "    $_" } }
    }
}

Write-Output ("[test] suites={0} passed={1} failed={2} skipped={3}" -f @($suites).Count, $passed, $failed, $skipped)
if ($problems) { Write-Output "[test] FAILED: $($problems -join ', ')"; exit 1 }
exit 0
