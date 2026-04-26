# ============================================================
#  PrintHub Auto-Start Installer
#  Run this ONCE on each PC as Administrator:
#  Right-click install-autostart.ps1 → "Run with PowerShell"
# ============================================================

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$NodeExe    = (Get-Command node -ErrorAction SilentlyContinue)?.Source

if (-not $NodeExe) {
    # Try common locations
    $candidates = @(
        "S:\node.js\node.exe",
        "C:\Program Files\nodejs\node.exe",
        "C:\Program Files (x86)\nodejs\node.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $NodeExe = $c; break }
    }
}

if (-not $NodeExe) {
    Write-Host "ERROR: node.exe not found. Install Node.js first." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PrintHub Auto-Start Installer" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project folder : $ProjectDir"
Write-Host "Node.exe       : $NodeExe"
Write-Host ""

# Create logs folder
New-Item -ItemType Directory -Path "$ProjectDir\logs" -Force | Out-Null

# ── Task 1: PrintHub Server ───────────────────────────────────
$serverAction  = New-ScheduledTaskAction `
    -Execute    $NodeExe `
    -Argument   "server\server.js" `
    -WorkingDirectory $ProjectDir

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Hours 0) `
    -RestartCount 5 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false

$principal = New-ScheduledTaskPrincipal `
    -UserId    "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel  Highest

# Remove old task if exists
Unregister-ScheduledTask -TaskName "PrintHub-Server" -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName   "PrintHub-Server" `
    -TaskPath   "\PrintHub\" `
    -Action     $serverAction `
    -Trigger    $trigger `
    -Settings   $settings `
    -Principal  $principal `
    -Description "PrintHub web server — starts automatically at boot" | Out-Null

Write-Host "✅ PrintHub Server task registered" -ForegroundColor Green

# ── Task 2: PrintHub Print Agent ─────────────────────────────
$agentAction = New-ScheduledTaskAction `
    -Execute    $NodeExe `
    -Argument   "print-agent\printAgent.js" `
    -WorkingDirectory $ProjectDir

# Agent starts 15 seconds after boot (gives server time to start first)
$agentTrigger = New-ScheduledTaskTrigger -AtStartup
$agentTrigger.Delay = "PT15S"

Unregister-ScheduledTask -TaskName "PrintHub-Agent" -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName   "PrintHub-Agent" `
    -TaskPath   "\PrintHub\" `
    -Action     $agentAction `
    -Trigger    $agentTrigger `
    -Settings   $settings `
    -Principal  $principal `
    -Description "PrintHub print agent — polls server and sends jobs to printer" | Out-Null

Write-Host "✅ PrintHub Print Agent task registered" -ForegroundColor Green

# ── Start both tasks right now ────────────────────────────────
Write-Host ""
Write-Host "Starting services now..." -ForegroundColor Yellow

Start-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Server"
Start-Sleep -Seconds 3
Start-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Agent"

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Both services will now start automatically every time this PC boots."
Write-Host "No terminal needed. No manual steps."
Write-Host ""
Write-Host "To check status, run: .\check-status.ps1"
Write-Host "To stop services,  run: .\stop-services.ps1"
Write-Host ""
Read-Host "Press Enter to close"
