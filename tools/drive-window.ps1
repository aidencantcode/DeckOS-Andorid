# DeckOS dev tool (Windows): drives the PC build with posted key presses and saves window screenshots.
# Example: tools/drive-window.ps1 -Exe ../windows-build/DeckOS.exe -WorkDir ../windows-build -OutDir shots -Steps "size:1920x1080","wait:6000","key:F1","shot:menu"
# Launches an exe, posts a key script to its main window and captures screenshots.
# Steps: "key:F1", "key:DOWN", "key:RETURN", "wait:1500", "shot:name", "tap:F1:80" (press, then wait 80 ms)
param([string]$Exe, [string]$WorkDir, [string]$OutDir, [string[]]$Steps, [int]$StartupSeconds = 6)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class W32 {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
}
"@
$keys = @{ F1 = @(0x70, 0x3B, 0); DOWN = @(0x28, 0x50, 1); UP = @(0x26, 0x48, 1); LEFT = @(0x25, 0x4B, 1); RIGHT = @(0x27, 0x4D, 1);
           RETURN = @(0x0D, 0x1C, 0); ESCAPE = @(0x1B, 0x01, 0); BACKSPACE = @(0x08, 0x0E, 0); PGUP = @(0x21, 0x49, 1);
           Y = @(0x59, 0x15, 0); X = @(0x58, 0x2D, 0); F = @(0x46, 0x21, 0); I = @(0x49, 0x17, 0); PGDN = @(0x22, 0x51, 1) }

function Send-Key($h, [string]$name) {
    $k = $keys[$name]
    $l = 1 -bor ($k[1] -shl 16) -bor ($k[2] -shl 24)
    [void][W32]::PostMessage($h, 0x0100, [IntPtr]$k[0], [IntPtr]$l)                       # WM_KEYDOWN
    Start-Sleep -Milliseconds 60
    $lu = [int64]$l -bor (1 -shl 30) -bor ([int64]1 -shl 31)
    [void][W32]::PostMessage($h, 0x0101, [IntPtr]$k[0], [IntPtr][int64]$lu)               # WM_KEYUP
}

function Save-Shot($h, [string]$name) {
    $r = New-Object W32+RECT
    [void][W32]::GetClientRect($h, [ref]$r)
    $bmp = New-Object System.Drawing.Bitmap(($r.Right - $r.Left), ($r.Bottom - $r.Top))
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdc = $g.GetHdc(); $ok = [W32]::PrintWindow($h, $hdc, 3); $g.ReleaseHdc($hdc); $g.Dispose()
    $path = Join-Path $OutDir "$name.png"
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Write-Output "shot $name ok=$ok"
}

# Safety: synthetic keys must never be able to reach Quit -> Shutdown/Reboot/Suspend on this PC.
$p = Start-Process -FilePath $Exe -WorkingDirectory $WorkDir -PassThru `
    -ArgumentList '--disable-menu-shutdown', '--disable-menu-reboot', '--disable-menu-suspend'
try {
    Start-Sleep -Seconds $StartupSeconds
    $p.Refresh(); $h = $p.MainWindowHandle
    if ($h -eq [IntPtr]::Zero) { throw 'no main window' }
    foreach ($s in ($Steps -join ',') -split ',') {
        $kind, $arg = $s -split ':', 2
        switch ($kind) {
            'key'  { Send-Key $h $arg; Start-Sleep -Milliseconds 400 }
            'tap'  { $kn, $ms = $arg -split ':', 2; Send-Key $h $kn; Start-Sleep -Milliseconds ([int]$ms) } # "tap:F1:80" = quick presses
            'wait' { Start-Sleep -Milliseconds ([int]$arg) }
            'shot' { Save-Shot $h $arg }
            'size' {   # client area WxH
                $wh = $arg -split 'x'; $wr = New-Object W32+RECT; $cr = New-Object W32+RECT
                [void][W32]::GetWindowRect($h, [ref]$wr); [void][W32]::GetClientRect($h, [ref]$cr)
                $fw = ($wr.Right - $wr.Left) - $cr.Right; $fh = ($wr.Bottom - $wr.Top) - $cr.Bottom
                [void][W32]::SetWindowPos($h, [IntPtr]::Zero, 0, 0, [int]$wh[0] + $fw, [int]$wh[1] + $fh, 0x0014)
                Start-Sleep -Milliseconds 1200
            }
            'click' {  # x,y in client pixels
                $xy = $arg -split ';'; $lp = ([int]$xy[1] -shl 16) -bor [int]$xy[0]
                [void][W32]::PostMessage($h, 0x0201, [IntPtr]1, [IntPtr]$lp); Start-Sleep -Milliseconds 50
                [void][W32]::PostMessage($h, 0x0202, [IntPtr]0, [IntPtr]$lp); Start-Sleep -Milliseconds 400
            }
        }
    }
} finally {
    # close normally first so the app flushes config\lastrun.log; kill only if it hangs
    if (-not $p.HasExited -and $h) { [void][W32]::PostMessage($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    if (-not $p.WaitForExit(8000)) { Write-Output "[drive] app did not exit within 8 s - killed (log may be incomplete)"; Stop-Process -Id $p.Id -Force }
    else { Write-Output "[drive] app exited ($($p.ExitCode))" }
}
