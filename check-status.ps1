# ============================================================
#  PrintHub Status Checker
#  Double-click or run: .\check-status.ps1
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  PrintHub Service Status" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check scheduled tasks
$tasks = @("PrintHub-Server", "PrintHub-Agent")
foreach ($name in $tasks) {
    $task = Get-ScheduledTask -TaskPath "\PrintHub\" -TaskName $name -ErrorAction SilentlyContinue
    if ($task) {
        $info = Get-ScheduledTaskInfo -TaskPath "\PrintHub\" -TaskName $name
        $state = $task.State
        $lastRun = $info.LastRunTime
        $lastResult = $info.LastTaskResult

        $color = if ($state -eq "Running") { "Green" } else { "Red" }
        Write-Host "  $name" -ForegroundColor $color
        Write-Host "    State      : $state" -ForegroundColor $color
        Write-Host "    Last run   : $lastRun"
        Write-Host "    Last result: $(if ($lastResult -eq 0) { 'Success' } else { "Code $lastResult" })"
        Write-Host ""
    } else {
        Write-Host "  $name : NOT INSTALLED" -ForegroundColor Red
        Write-Host "    Run install-autostart.ps1 to set up auto-start." -ForegroundColor Yellow
        Write-Host ""
    }
}

# Check if ports are listening
Write-Host "  Port checks:" -ForegroundColor Cyan
$port3000 = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
$port5000 = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue

if ($port3000) {
    Write-Host "    Port 3000 (Server) : LISTENING ✅" -ForegroundColor Green
} else {
    Write-Host "    Port 3000 (Server) : NOT listening ❌" -ForegroundColor Red
}

if ($port5000) {
    Write-Host "    Port 5000 (Agent)  : LISTENING ✅" -ForegroundColor Green
} else {
    Write-Host "    Port 5000 (Agent)  : not used (agent polls, no port needed)" -ForegroundColor Gray
}

Write-Host ""

# Show last 5 lines of logs
$logDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "logs"
foreach ($log in @("server.log", "agent.log")) {
    $logPath = Join-Path $logDir $log
    if (Test-Path $logPath) {
        Write-Host "  Last lines of $log :" -ForegroundColor Cyan
        Get-Content $logPath -Tail 5 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        Write-Host ""
    }
}

Read-Host "Press Enter to close"
