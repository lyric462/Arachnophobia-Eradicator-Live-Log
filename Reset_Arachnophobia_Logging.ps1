$ErrorActionPreference = "Stop"

$gameDir = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $gameDir "content\content0\x64.final.redscripts"
$backupDir = Join-Path $gameDir "ArachnophobiaLogViewer\ScriptCacheBackup"

New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

if (Test-Path -LiteralPath $cache) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = Join-Path $backupDir ("x64.final.redscripts." + $stamp + ".bak")
    Move-Item -LiteralPath $cache -Destination $backup -Force
    Write-Host "Script cache backed up to:"
    Write-Host $backup
}
else {
    Write-Host "No x64.final.redscripts cache found."
}

$marker = Join-Path $gameDir "ArachnophobiaLogViewer\logging_ready.flag"
if (Test-Path -LiteralPath $marker) {
    Remove-Item -LiteralPath $marker -Force
}

Write-Host ""
Write-Host "Logging cache reset complete."
Write-Host "The next launch through Start_Witcher3_Arachnophobia.cmd will rebuild it with -debugscripts."
pause
