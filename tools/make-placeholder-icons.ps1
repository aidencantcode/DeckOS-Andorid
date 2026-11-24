# Renders DeckOS's PLACEHOLDER app icon - a "D" with an accent button - into every icon slot the app uses:
# Android launcher icons (legacy + adaptive foreground), the Android TV banner, the window icon and the
# Windows .ico. Drawn from plain shapes (no fonts, no third-party art). The final artwork comes with the
# Phase 7 original-assets pass; re-run this after changing the colours or shape.
# Usage:  tools\make-placeholder-icons.ps1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$android = Join-Path $root 'src\app\platform\android\res'

# Keep in sync with deckos_bg in src/app/platform/android/res/values/colors.xml (adaptive icon + splash).
$Bg     = [System.Drawing.ColorTranslator]::FromHtml('#121822')
$Fg     = [System.Drawing.ColorTranslator]::FromHtml('#E8EEF7')
$Accent = [System.Drawing.ColorTranslator]::FromHtml('#3D8BFF')

function New-Canvas([int]$W, [int]$H) {
    $bmp = New-Object System.Drawing.Bitmap($W, $H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return @{ Bitmap = $bmp; Graphics = $g }
}

# The mark: a stroked "D" (height = $S) with a filled accent dot in its middle, centred on ($Cx, $Cy).
function Add-Mark($g, [double]$Cx, [double]$Cy, [double]$S) {
    $w = 0.2 * $S                         # stroke width
    $left = $Cx - 0.41 * $S; $top = $Cy - 0.5 * $S
    $x0 = $left + $w / 2; $y0 = $top + $w / 2
    $y1 = $top + $S - $w / 2
    $r  = ($y1 - $y0) / 2
    $xm = $x0 + 0.22 * $S                 # where the straight top/bottom edges turn into the arc

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddLine([single]$x0, [single]$y0, [single]$xm, [single]$y0)
    $path.AddArc([single]($xm - $r), [single]$y0, [single](2 * $r), [single](2 * $r), -90, 180)
    $path.AddLine([single]$xm, [single]$y1, [single]$x0, [single]$y1)
    $path.CloseFigure()
    $pen = New-Object System.Drawing.Pen($Fg, [single]$w)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($pen, $path)

    $d = 0.2 * $S
    $brush = New-Object System.Drawing.SolidBrush($Accent)
    $g.FillEllipse($brush, [single]($Cx - $d / 2 + 0.02 * $S), [single]($Cy - $d / 2), [single]$d, [single]$d)
    $pen.Dispose(); $brush.Dispose(); $path.Dispose()
}

# Legacy square icon: rounded tile + mark.
function New-TileIcon([int]$N) {
    $c = New-Canvas $N $N
    $m = 0.04 * $N; $rad = 0.22 * $N; $side = $N - 2 * $m
    $tile = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tile.AddArc([single]$m, [single]$m, [single]$rad, [single]$rad, 180, 90)
    $tile.AddArc([single]($m + $side - $rad), [single]$m, [single]$rad, [single]$rad, 270, 90)
    $tile.AddArc([single]($m + $side - $rad), [single]($m + $side - $rad), [single]$rad, [single]$rad, 0, 90)
    $tile.AddArc([single]$m, [single]($m + $side - $rad), [single]$rad, [single]$rad, 90, 90)
    $tile.CloseFigure()
    $brush = New-Object System.Drawing.SolidBrush($Bg)
    $c.Graphics.FillPath($brush, $tile)
    Add-Mark $c.Graphics ($N / 2) ($N / 2) (0.5 * $N)
    $brush.Dispose(); $tile.Dispose(); $c.Graphics.Dispose()
    return $c.Bitmap
}

# Adaptive-icon foreground (108dp canvas; launchers mask it to the central ~66dp): mark only.
function New-ForegroundIcon([int]$N) {
    $c = New-Canvas $N $N
    Add-Mark $c.Graphics ($N / 2) ($N / 2) (0.4 * $N)
    $c.Graphics.Dispose()
    return $c.Bitmap
}

function New-Banner([int]$W, [int]$H) {
    $c = New-Canvas $W $H
    $c.Graphics.Clear($Bg)
    Add-Mark $c.Graphics ($W / 2) ($H / 2) (0.6 * $H)
    $c.Graphics.Dispose()
    return $c.Bitmap
}

function Save-Png($Bitmap, [string]$Path) {
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $Bitmap.Dispose()
    Write-Output "  $($Path.Substring($root.Length + 1))"
}

# One .ico entry: PNG for 256 px (Vista+ convention), a classic 32-bit DIB below that (readable everywhere).
function Get-IcoEntry([int]$N) {
    $b = New-TileIcon $N
    $ms = New-Object System.IO.MemoryStream
    if ($N -ge 256) { $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose(); return , $ms.ToArray() }
    $bw = New-Object System.IO.BinaryWriter($ms)
    $maskRow = [int][Math]::Floor(($N + 31) / 32) * 4
    # BITMAPINFOHEADER; height is doubled because the AND mask follows the colour data
    $bw.Write([uint32]40); $bw.Write([int32]$N); $bw.Write([int32](2 * $N)); $bw.Write([uint16]1); $bw.Write([uint16]32)
    $bw.Write([uint32]0); $bw.Write([uint32]($N * $N * 4 + $maskRow * $N)); $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write([uint32]0); $bw.Write([uint32]0)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $N, $N)
    $data = $b.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $row = New-Object byte[] ($N * 4)
    for ($y = $N - 1; $y -ge 0; $y--) {                 # DIBs are stored bottom-up; BGRA order matches
        [System.Runtime.InteropServices.Marshal]::Copy([IntPtr]($data.Scan0.ToInt64() + $y * $data.Stride), $row, 0, $N * 4)
        $bw.Write($row)
    }
    $b.UnlockBits($data); $b.Dispose()
    $bw.Write((New-Object byte[] ($maskRow * $N)))      # AND mask all zero: transparency comes from alpha
    $bw.Flush()
    return , $ms.ToArray()
}

# A Windows .ico with one entry per size.
function Save-Ico([int[]]$Sizes, [string]$Path) {
    $pngs = foreach ($s in $Sizes) { , (Get-IcoEntry $s) }
    $out = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($out)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$Sizes.Count)
    $offset = 6 + 16 * $Sizes.Count
    for ($i = 0; $i -lt $Sizes.Count; $i++) {
        $dim = if ($Sizes[$i] -ge 256) { 0 } else { $Sizes[$i] }   # 0 means 256
        $bw.Write([byte]$dim); $bw.Write([byte]$dim); $bw.Write([byte]0); $bw.Write([byte]0)
        $bw.Write([uint16]1); $bw.Write([uint16]32)
        $bw.Write([uint32]$pngs[$i].Length); $bw.Write([uint32]$offset)
        $offset += $pngs[$i].Length
    }
    foreach ($p in $pngs) { $bw.Write($p) }
    $bw.Flush()
    [IO.File]::WriteAllBytes($Path, $out.ToArray())
    $bw.Dispose()
    Write-Output "  $($Path.Substring($root.Length + 1))"
}

Write-Output 'DeckOS placeholder icons:'
$legacy = @{ 'ldpi' = 36; 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($k in $legacy.Keys) { Save-Png (New-TileIcon $legacy[$k]) (Join-Path $android "mipmap-$k\icon.png") }
$adaptive = @{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($k in $adaptive.Keys) { Save-Png (New-ForegroundIcon $adaptive[$k]) (Join-Path $android "mipmap-$k\icon_fg.png") }
Save-Png (New-Banner 320 180) (Join-Path $android 'mipmap-xhdpi\banner.png')
Save-Png (New-TileIcon 128) (Join-Path $root 'assets\icon.png')
Save-Ico @(16, 24, 32, 48, 64, 128, 256) (Join-Path $root 'src\app\platform\windows\app_icon.ico')
