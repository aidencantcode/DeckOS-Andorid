# DeckOS dev tool (Windows): does the Android side compile? Checked here in minutes instead of waiting
# for GitHub's APK build. Not a release build: releases still come from GitHub (tools/ship.ps1), which
# uses Pegasus's own Qt 5.15.10 for Android on Linux; this uses the official Qt 5.15.2 for Android.
#
#   tools\check-android.ps1             the Java (DeckOS's and Pegasus's), then the whole app's C++ for
#                                       arm64 with NDK r21e (incremental; the first run takes a while)
#   tools\check-android.ps1 -JavaOnly   just the Java, in seconds
#   tools\check-android.ps1 -Apk        also packages an unsigned APK (build-android\installdir)
#
# Toolchain (..\toolchain, never committed): jdk-17, android-sdk (platform 30, build-tools 30.0.3,
# ndk 21.4.7075529), Qt\5.15.2\android, android-libs (AndroidX core + annotation, OpenSSL for Android).
# Exit code 0 = it compiles.
param([switch]$JavaOnly, [switch]$Apk, [int]$Jobs = [Environment]::ProcessorCount)
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$tc = if ($env:DECKOS_TOOLCHAIN) { $env:DECKOS_TOOLCHAIN } else { Join-Path $root '..\toolchain' }
$tc = (Resolve-Path $tc).Path
$jdk = Join-Path $tc 'jdk-17'
$sdk = Join-Path $tc 'android-sdk'
$ndk = Join-Path $sdk 'ndk\21.4.7075529'
$qt = Join-Path $tc 'Qt\5.15.2\android'
$libs = Join-Path $tc 'android-libs'
$androidJar = Join-Path $sdk 'platforms\android-30\android.jar'
$buildDir = Join-Path $root '..\build-android'
foreach ($p in @($jdk, $androidJar, $qt, (Join-Path $libs 'androidx-core-1.6.0.jar'))) {
    if (-not (Test-Path $p)) { throw "Missing toolchain component: $p (see docs/03-dev-loop.md)" }
}
New-Item -ItemType Directory -Force $buildDir | Out-Null
$buildDir = (Resolve-Path $buildDir).Path
$env:JAVA_HOME = $jdk


# --- Java -------------------------------------------------------------------------------------------
# javac over every Android source DeckOS ships (src/app/platform/android/src) plus Qt's activity
# bindings they extend, against Android 11 (API 30), Qt's Java classes and AndroidX. The resource
# class R is a stub made from res/ (aapt would need the whole Gradle setup).

function New-RStub([string]$resDir, [string]$outDir) {
    $fields = @{}
    foreach ($d in Get-ChildItem $resDir -Directory) {
        $type = ($d.Name -split '-')[0]
        if ($type -eq 'values') {
            foreach ($f in Get-ChildItem $d.FullName -Filter *.xml) {
                [xml]$x = Get-Content $f.FullName -Raw
                foreach ($n in $x.resources.ChildNodes) {
                    if ($n.NodeType -ne 'Element' -or -not $n.name) { continue }
                    $t = switch ($n.LocalName) { 'string-array' { 'array' } 'integer-array' { 'array' } 'item' { $n.type } default { $n.LocalName } }
                    if (-not $t) { continue }
                    if (-not $fields[$t]) { $fields[$t] = New-Object System.Collections.Generic.HashSet[string] }
                    [void]$fields[$t].Add(($n.name -replace '[.:]', '_'))
                }
            }
        }
        else {
            if (-not $fields[$type]) { $fields[$type] = New-Object System.Collections.Generic.HashSet[string] }
            foreach ($f in Get-ChildItem $d.FullName -File) { [void]$fields[$type].Add(($f.Name -split '\.')[0]) }
        }
    }
    $id = 0x7f010000
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('package org.pegasus_frontend.android;')
    [void]$sb.AppendLine('public final class R {')
    foreach ($t in ($fields.Keys | Sort-Object)) {
        [void]$sb.AppendLine("    public static final class $t {")
        foreach ($n in ($fields[$t] | Sort-Object)) { [void]$sb.AppendLine("        public static final int $n = $id;"); $id++ }
        [void]$sb.AppendLine('    }')
    }
    [void]$sb.AppendLine('}')
    $dir = Join-Path $outDir 'org\pegasus_frontend\android'
    New-Item -ItemType Directory -Force $dir | Out-Null
    [IO.File]::WriteAllText((Join-Path $dir 'R.java'), $sb.ToString())
}

$javaOut = Join-Path $buildDir 'javacheck'
if (Test-Path $javaOut) { Remove-Item -Recurse -Force $javaOut }
New-Item -ItemType Directory -Force (Join-Path $javaOut 'gen'), (Join-Path $javaOut 'classes') | Out-Null
$androidSrc = Join-Path $root 'src\app\platform\android'
New-RStub (Join-Path $androidSrc 'res') (Join-Path $javaOut 'gen')
# Qt's loader uses its Ministro AIDL interfaces: generated as Gradle would
$qtJavaSrc = Join-Path $qt 'src\android\java\src'
$aidl = Join-Path $sdk 'build-tools\30.0.3\aidl.exe'
foreach ($f in Get-ChildItem $qtJavaSrc -Recurse -Filter *.aidl) {
    & $aidl "-p$sdk\platforms\android-30\framework.aidl" "-I$qtJavaSrc" "-o$javaOut\gen" $f.FullName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "aidl failed on $($f.Name)" }
}
$sources = @(Get-ChildItem (Join-Path $androidSrc 'src'), (Join-Path $javaOut 'gen'), (Join-Path $qt 'src\android\java\src\org\qtproject\qt5\android\bindings') -Recurse -Filter *.java | ForEach-Object { '"' + ($_.FullName -replace '\\', '/') + '"' })
Set-Content -Path (Join-Path $javaOut 'sources.txt') -Value $sources -Encoding Ascii
$cp = @((Join-Path $qt 'jar\QtAndroid.jar'), (Join-Path $libs 'androidx-core-1.6.0.jar'), (Join-Path $libs 'androidx-annotation-1.2.0.jar')) -join ';'
$start = Get-Date
# android.jar has no LambdaMetafactory: like Gradle, compile lambdas against build-tools' stubs
$boot = "$androidJar;" + (Join-Path $sdk 'build-tools\30.0.3\core-lambda-stubs.jar')
cmd /c "`"$jdk\bin\javac.exe`" -source 8 -target 8 -bootclasspath `"$boot`" -classpath `"$cp`" -encoding UTF-8 -nowarn -Xlint:-options -Xmaxerrs 200 -d `"$javaOut\classes`" @`"$javaOut\sources.txt`" > `"$javaOut\javac.log`" 2>&1"
$javaCode = $LASTEXITCODE
$javaErrors = @(Select-String -Path (Join-Path $javaOut 'javac.log') -Pattern 'error:' | ForEach-Object { $_.Line })
Write-Output ("[java] {0} files, exit={1}, errors={2}, {3:0.0}s" -f $sources.Count, $javaCode, $javaErrors.Count, ((Get-Date) - $start).TotalSeconds)
if ($javaCode -ne 0) { Get-Content (Join-Path $javaOut 'javac.log') | Select-Object -First 60 }
if ($JavaOnly) { exit $javaCode }


# --- C++ (arm64) ------------------------------------------------------------------------------------
# qmake's android-clang Makefiles on a Windows host expect cmd.exe (no sh.exe on PATH), but the app's
# post-link step runs sed: a sed.cmd shim calls Git's own sed.exe.

$gitExe = (Get-Command git -ErrorAction Stop).Source
$gitSed = Join-Path (Split-Path (Split-Path $gitExe)) 'usr\bin\sed.exe'
if (-not (Test-Path $gitSed)) { throw "Git's sed.exe not found at $gitSed" }
$shim = Join-Path $buildDir 'shim'
New-Item -ItemType Directory -Force $shim | Out-Null
Set-Content -Path (Join-Path $shim 'sed.cmd') -Value "@`"$gitSed`" %*" -Encoding Ascii

$env:ANDROID_NDK_ROOT = $ndk
$env:ANDROID_SDK_ROOT = $sdk
$env:Path = @((Join-Path $qt 'bin'), (Join-Path $ndk 'prebuilt\windows-x86_64\bin'), $shim, (Split-Path $gitExe), (Join-Path $jdk 'bin'),
              "$env:SystemRoot\System32", $env:SystemRoot, "$env:SystemRoot\System32\WindowsPowerShell\v1.0") -join ';'

Push-Location $buildDir
try {
    if (-not (Test-Path 'Makefile')) {
        $ssl = $libs -replace '\\', '/'
        cmd /c "qmake.exe `"$root\pegasus.pro`" -spec android-clang ANDROID_ABIS=arm64-v8a FORCE_QT_PNG=1 OPENSSL_ANDROID_DIR=$ssl `"QMAKE_CXXFLAGS+=-Wall -Wextra`" > qmake.log 2>&1"
        if ($LASTEXITCODE -ne 0) { Get-Content qmake.log -Tail 30; throw "qmake failed ($LASTEXITCODE)" }
    }
    $makefileTime = (Get-Item 'Makefile').LastWriteTime
    $newer = Get-ChildItem (Join-Path $root 'src') -Recurse -File -Include *.qrc, *.pro, *.pri |
        Where-Object { $_.LastWriteTime -gt $makefileTime } | Select-Object -First 1
    if ($newer) {
        Write-Output "[android] $($newer.Name) changed - regenerating Makefiles"
        cmd /c "make.exe qmake_all > qmake_all.log 2>&1"
        if ($LASTEXITCODE -ne 0) { Get-Content qmake_all.log -Tail 30; throw "qmake_all failed ($LASTEXITCODE)" }
        (Get-Item 'Makefile').LastWriteTime = Get-Date
    }

    $start = Get-Date
    cmd /c "make.exe -j$Jobs > make.log 2>&1"
    $code = $LASTEXITCODE
    $errors = @(Select-String -Path make.log -Pattern ' error:|error: |Error \d+' | ForEach-Object { $_.Line } | Select-Object -Unique)
    $own = @(Select-String -Path make.log -Pattern 'warning:' | Where-Object { $_.Line -like "*$root\src\*" -or $_.Line -like "*src/backend/deckos*" } | ForEach-Object { $_.Line } | Sort-Object -Unique)
    Write-Output ("[c++] arm64 exit={0}, errors={1}, own warnings={2}, {3}s (log: {4})" -f $code, $errors.Count, $own.Count, [int]((Get-Date) - $start).TotalSeconds, (Join-Path $buildDir 'make.log'))
    if ($code -ne 0) { $errors | Select-Object -First 40 }
    $own | Select-Object -First 20

    if ($code -eq 0 -and $Apk) {
        cmd /c "make.exe install INSTALL_ROOT=`"$buildDir\installdir`" > install.log 2>&1"
        if ($LASTEXITCODE -ne 0) { Get-Content install.log -Tail 20; throw "make install failed" }
        $settings = Get-ChildItem $buildDir -Recurse -Filter 'android-*-deployment-settings.json' | Select-Object -First 1
        # a Gradle daemon left behind by androiddeployqt keeps this script's output pipe open
        $env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
        cmd /c "androiddeployqt.exe --input `"$($settings.FullName)`" --output `"$buildDir\installdir`" --android-platform android-30 --jdk `"$jdk`" --gradle > deploy.log 2>&1"
        $apkCode = $LASTEXITCODE
        # Qt 5.15.2's Gradle wrapper (5.6.4) runs neither on JDK 17 nor with DeckOS's Android Gradle
        # plugin 7.0.2 (CI's Qt 5.15.10 ships a newer one): androiddeployqt has copied everything by
        # then, so the wrapper is moved to Gradle 7.3.3 and Gradle runs again
        $wrapper = Join-Path $buildDir 'installdir\gradle\wrapper\gradle-wrapper.properties'
        if ($apkCode -ne 0 -and (Test-Path $wrapper)) {
            (Get-Content $wrapper) -replace 'gradle-[0-9.]+-(bin|all)\.zip', 'gradle-7.3.3-bin.zip' | Set-Content $wrapper -Encoding Ascii
            # Qt 5.15.2 also leaves out androidNdkVersion, which DeckOS's build.gradle reads
            $props = Join-Path $buildDir 'installdir\gradle.properties'
            if (-not (Select-String -Path $props -Pattern '^androidNdkVersion=' -Quiet)) {
                Add-Content $props ("androidNdkVersion=" + (Split-Path $ndk -Leaf)) -Encoding Ascii
            }
            $env:JAVA_HOME = $jdk
            Push-Location (Join-Path $buildDir 'installdir')
            try { cmd /c ".\gradlew.bat --no-daemon assembleDebug > ..\gradle.log 2>&1" }
            finally { Pop-Location }
            $apkCode = $LASTEXITCODE
            if ($apkCode -ne 0) { Get-Content (Join-Path $buildDir 'gradle.log') -Tail 30 }
        }
        $apkFile = Get-ChildItem (Join-Path $buildDir 'installdir\build\outputs\apk') -Recurse -Filter *.apk -ErrorAction SilentlyContinue | Select-Object -First 1
        Write-Output ("[apk] exit={0} {1}" -f $apkCode, $(if ($apkFile) { $apkFile.FullName } else { '(none - see deploy.log)' }))
        if ($apkCode -ne 0) { Get-Content deploy.log -Tail 30 }
        if ($apkCode -ne 0) { $code = $apkCode }
    }
}
finally {
    Pop-Location
}

if ($javaCode -ne 0) { exit $javaCode }
exit $code
