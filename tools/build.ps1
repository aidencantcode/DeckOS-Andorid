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
        & qmake.exe $DeckosRoot USE_SDL_GAMEPAD=1 USE_SDL_POWER=1 `
            "SDL_LIBS=-L$sdl/lib -lSDL2" "SDL_INCLUDES=$sdl/include/SDL2" `
            'QMAKE_CXXFLAGS+=-Wall -Wextra -pedantic' 2>&1 | Out-File -Encoding utf8 qmake.log
        if ($LASTEXITCODE -ne 0) { Get-Content qmake.log -Tail 20; throw "qmake failed ($LASTEXITCODE)" }
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
