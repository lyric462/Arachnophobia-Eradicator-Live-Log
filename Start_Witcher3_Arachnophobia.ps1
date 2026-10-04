$ErrorActionPreference = "SilentlyContinue"

$gameDir = Split-Path -Parent $PSScriptRoot
$content0 = Join-Path $gameDir "content\content0"
$compileCache = Join-Path $content0 "x64.final.redscripts"
$backupDir = Join-Path $gameDir "ArachnophobiaLogViewer\ScriptCacheBackup"
$marker = Join-Path $gameDir "ArachnophobiaLogViewer\logging_ready.flag"
$viewer = Join-Path $gameDir "ArachnophobiaLogViewer\Arachnophobia_LogViewer.ps1"

# --------------------------------------------
# First-run logging repair for Remastered.
#
# The Remastered mod build can keep a compiled script cache in
# content\content0\x64.final.redscripts. If that cache was created without
# script logging enabled, LogChannel() entries may not appear in scriptlog.
#
# We move the cache to a timestamped backup instead of deleting it.
# The game will regenerate it on this launch with -debugscripts.
# --------------------------------------------
if (!(Test-Path -LiteralPath $marker)) {
    if (Test-Path -LiteralPath $compileCache) {
        New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

        $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backup = Join-Path $backupDir ("x64.final.redscripts." + $stamp + ".bak")

        Move-Item -LiteralPath $compileCache -Destination $backup -Force
    }

    # Create the marker so the expensive cache rebuild happens only once.
    Set-Content -LiteralPath $marker -Value (
        "Logging repair performed " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    ) -Encoding UTF8
}

# Start live viewer.
Start-Process -FilePath "powershell.exe" `
    -ArgumentList @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$viewer`""
    ) | Out-Null

Start-Sleep -Milliseconds 700

# Find Steam.
$steam = $null

$regPaths = @(
    "HKCU:\Software\Valve\Steam",
    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam"
)

foreach ($p in $regPaths) {
    try {
        $candidate = (Get-ItemProperty -Path $p -Name SteamExe -ErrorAction Stop).SteamExe
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            $steam = $candidate
            break
        }
    } catch {}
}

if (!$steam) {
    $defaults = @(
        "$env:ProgramFiles(x86)\Steam\steam.exe",
        "$env:ProgramFiles\Steam\steam.exe"
    )

    foreach ($candidate in $defaults) {
        if (Test-Path -LiteralPath $candidate) {
            $steam = $candidate
            break
        }
    }
}

if (!$steam) {
    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        "Steam was not found.`n`nPlease start Steam and The Witcher 3 manually with -debugscripts for the live log.",
        "Arachnophobia Eradicator"
    ) | Out-Null
    exit 1
}

# Witcher 3 Steam AppID: 292030.
# -debugscripts enables script logging for this launch.
Start-Process -FilePath $steam `
    -ArgumentList @(
        "-applaunch",
        "292030",
        "-debugscripts"
    ) | Out-Null
