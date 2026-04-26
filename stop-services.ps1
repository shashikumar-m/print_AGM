# ============================================================
#  Stop PrintHub Services
# ============================================================

Write-Host "Stopping PrintHub services..." -ForegroundColor Yellow

Stop-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Agent" -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Server" -ErrorAction SilentlyContinue

# Also kill any lingering node processes running our scripts
Get-Process -Name "node" -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
    if ($cmd -match "server\.js|printAgent\.js") {
        Write-Host "  Stopping node process: $cmd" -ForegroundColor Gray
        $_ | Stop-Process -Force
    }
}

Write-Host "✅ Services stopped." -ForegroundColor Green
Read-Host "Press Enter to close"
