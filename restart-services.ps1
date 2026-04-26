# ============================================================
#  Restart PrintHub Services (useful after code updates)
# ============================================================

Write-Host "Restarting PrintHub services..." -ForegroundColor Yellow

# Stop
Stop-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Agent"  -ErrorAction SilentlyContinue
Stop-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Server" -ErrorAction SilentlyContinue

Get-Process -Name "node" -ErrorAction SilentlyContinue | ForEach-Object {
    $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine
    if ($cmd -match "server\.js|printAgent\.js") { $_ | Stop-Process -Force }
}

Start-Sleep -Seconds 2

# Start
Start-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Server"
Write-Host "  ✅ Server started" -ForegroundColor Green
Start-Sleep -Seconds 3
Start-ScheduledTask -TaskPath "\PrintHub\" -TaskName "PrintHub-Agent"
Write-Host "  ✅ Print Agent started" -ForegroundColor Green

Write-Host ""
Write-Host "Services restarted successfully." -ForegroundColor Green
Read-Host "Press Enter to close"
