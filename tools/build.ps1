# Build DeckOS on Windows (qmake + MinGW). Usage:  tools\build.ps1 [-Clean] [-Jobs N]
# Output: build\  (log: build\make.log). Exit code 0 = built.
param([switch]$Clean, [int]$Jobs = [Environment]::ProcessorCount)
. "$PSScriptRoot\env.ps1"

if ($Clean -and (Test-Path $BuildDir)) { Remove-Item -Recurse -Force $BuildDir }
New-Item -ItemType Directory -Force $BuildDir | Out-Null
Push-Location $BuildDir
try {
    if (-not (Test-Path 'Makefile')) {
        $sdl = $SdlDir -replace '\\', '/'
        # Through cmd: qmake prints normal "Project MESSAGE" lines on stderr, which PowerShell 5.1
        # turns into a terminating error under $ErrorActionPreference = 'Stop'.
        cmd /c "qmake.exe `"$DeckosRoot`" USE_SDL_GAMEPAD=1 USE_SDL_POWER=1 `"SDL_LIBS=-L$sdl/lib -lSDL2`" `"SDL_INCLUDES=$sdl/include/SDL2`" `"QMAKE_CXXFLAGS+=-Wall -Wextra -pedantic`" > qmake.log 2>&1"
        if ($LASTEXITCODE -ne 0) { Get-Content qmake.log -Tail 20; throw "qmake failed ($LASTEXITCODE)" }
    }

    # The Qt Quick Compiler's per-file rules come from qmake: after adding QML files to a .qrc (or
    # changing a .pro/.pri) every Makefile must be regenerated, or linking fails with undefined
    # QmlCacheGeneratedCode symbols.
    $makefileTime = (Get-Item 'Makefile').LastWriteTime
    $newer = Get-ChildItem (Join-Path $DeckosRoot 'src'), (Join-Path $DeckosRoot 'tests') -Recurse -File -Include *.qrc, *.pro, *.pri |
        Where-Object { $_.LastWriteTime -gt $makefileTime } | Select-Object -First 1
    if ($newer) {
        Write-Output "[build] $($newer.Name) changed - regenerating Makefiles"
        cmd /c "mingw32-make qmake_all > qmake_all.log 2>&1"
        if ($LASTEXITCODE -ne 0) { Get-Content qmake_all.log -Tail 20; throw "qmake_all failed ($LASTEXITCODE)" }
        (Get-Item 'Makefile').LastWriteTime = Get-Date
    }

    $start = Get-Date
    cmd /c "mingw32-make -j$Jobs > make.log 2>&1"
    $code = $LASTEXITCODE
    $secs = [int]((Get-Date) - $start).TotalSeconds

    # Warnings in our own tree matter; Qt's headers and thirdparty/ are upstream noise.
    $ownWarnings = Select-String -Path make.log -Pattern 'warning:' |
        Where-Object { $_.Line -like "$DeckosRoot\src\*" -or $_.Line -like "$DeckosRoot\tests\*" } |
        ForEach-Object { $_.Line } | Sort-Object -Unique
    $errors = Select-String -Path make.log -Pattern ' error:|Error \d+' | ForEach-Object { $_.Line }

    Write-Output ("[build] exit={0} time={1}s own-warnings={2} errors={3}" -f $code, $secs, @($ownWarnings).Count, @($errors).Count)
    $ownWarnings | Select-Object -First 20 | ForEach-Object { Write-Output "  W $_" }
    if ($code -ne 0) { $errors | Select-Object -First 20 | ForEach-Object { Write-Output "  E $_" } }
    exit $code
} finally { Pop-Location }
