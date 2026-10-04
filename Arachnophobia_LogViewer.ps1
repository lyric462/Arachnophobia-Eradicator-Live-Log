$ErrorActionPreference = "SilentlyContinue"

# Remastered/Next-Gen commonly uses scriptslog.txt (plural).
# Older setups may use scriptlog.txt (singular). Check both, including OneDrive Documents.
$candidates = @(
    (Join-Path $env:USERPROFILE "Documents\The Witcher 3\scriptslog.txt"),
    (Join-Path $env:USERPROFILE "Documents\The Witcher 3\scriptlog.txt"),
    (Join-Path $env:USERPROFILE "OneDrive\Documents\The Witcher 3\scriptslog.txt"),
    (Join-Path $env:USERPROFILE "OneDrive\Documents\The Witcher 3\scriptlog.txt")
)

$gameLog = $null

function Find-GameLog {
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) {
            return $p
        }
    }
    return $null
}

$cleanLog = Join-Path $PSScriptRoot "Arachnophobia_Kills.log"

# Move this console to the first non-primary monitor and fill that monitor.
try {
    Add-Type -AssemblyName System.Windows.Forms

    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class ArachnophobiaWindowTools {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(
        IntPtr hWnd,
        int X,
        int Y,
        int nWidth,
        int nHeight,
        bool bRepaint
    );
}
"@

    $secondary = [System.Windows.Forms.Screen]::AllScreens |
        Where-Object { -not $_.Primary } |
        Select-Object -First 1

    if ($secondary) {
        Start-Sleep -Milliseconds 250

        $r = $secondary.WorkingArea
        $hwnd = [ArachnophobiaWindowTools]::GetConsoleWindow()

        if ($hwnd -ne [IntPtr]::Zero) {
            [ArachnophobiaWindowTools]::MoveWindow(
                $hwnd,
                $r.X,
                $r.Y,
                $r.Width,
                $r.Height,
                $true
            ) | Out-Null
        }
    }
} catch {}

$Host.UI.RawUI.WindowTitle = "The Witcher 3 - Arachnophobia Live Log"

Clear-Host
Write-Host "=============================================================="
Write-Host " ARACHNOPHOBIA ERADICATOR - LIVE LOG"
Write-Host " English Nexus Build"
Write-Host "=============================================================="
Write-Host ""
Write-Host "Watching the game's script log..."
Write-Host "Press Ctrl+C to close this window."
Write-Host ""

try {
    Set-Content -LiteralPath $cleanLog -Value (
        "# Arachnophobia live log started " +
        (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    ) -Encoding UTF8
} catch {}

$lastPosition = 0
$seenGameLog = $null
$lastWaitNotice = Get-Date

while ($true) {
    if (!$gameLog -or !(Test-Path -LiteralPath $gameLog)) {
        $gameLog = Find-GameLog

        if ($gameLog -and $seenGameLog -ne $gameLog) {
            Write-Host "[LOG FOUND] $gameLog"
            $seenGameLog = $gameLog
            $lastPosition = 0
        }

        if (!$gameLog) {
            if (((Get-Date) - $lastWaitNotice).TotalSeconds -ge 5) {
                Write-Host "[WAITING] No script log found yet. Checking scriptlog.txt and scriptslog.txt..."
                $lastWaitNotice = Get-Date
            }
            Start-Sleep -Milliseconds 500
            continue
        }
    }

    try {
        $fileInfo = Get-Item -LiteralPath $gameLog

        # If the game recreated/truncated the file, start reading again.
        if ($fileInfo.Length -lt $lastPosition) {
            $lastPosition = 0
            Write-Host "[LOG RESET]"
        }

        $fs = New-Object System.IO.FileStream(
            $gameLog,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite
        )

        $fs.Seek($lastPosition, [System.IO.SeekOrigin]::Begin) | Out-Null

        $reader = New-Object System.IO.StreamReader(
            $fs,
            [System.Text.UTF8Encoding]::new($false, $false),
            $true
        )

        while (($line = $reader.ReadLine()) -ne $null) {
            if ($line -match "Arachnophobia") {
                Add-Content -LiteralPath $cleanLog -Value $line -Encoding UTF8

                # Friendly formatting for the most useful event types.
                if ($line -match "KILL \|") {
                    Write-Host "[KILL]    $line"
                }
                elseif ($line -match "SUMMARY \|") {
                    Write-Host "[SUMMARY] $line"
                }
                elseif ($line -match "HEARTBEAT \|") {
                    Write-Host "[STATUS]  $line"
                }
                elseif ($line -match "MOD STARTED") {
                    Write-Host "[START]   $line"
                }
                else {
                    Write-Host "[LOG]     $line"
                }
            }
        }

        $lastPosition = $fs.Position

        $reader.Dispose()
        $fs.Dispose()
    }
    catch {
        try { if ($reader) { $reader.Dispose() } } catch {}
        try { if ($fs) { $fs.Dispose() } } catch {}
    }

    Start-Sleep -Milliseconds 250
}
