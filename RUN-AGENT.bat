@echo off
:: PrintHub Print Agent — runs hidden in background
:: Double-click this file to start the print agent
:: It will keep running even after you close this window

set PROJECT=S:\project2\printer
set NODE=S:\node.js\node.exe

:: Check if already running
tasklist /FI "IMAGENAME eq node.exe" /FO CSV 2>NUL | find /I "node.exe" >NUL
if "%ERRORLEVEL%"=="0" (
    :: Check if our specific agent is running
    wmic process where "name='node.exe'" get commandline 2>NUL | find "printAgent" >NUL
    if "%ERRORLEVEL%"=="0" (
        echo Print Agent is already running.
        timeout /t 2 >NUL
        exit
    )
)

echo Starting PrintHub Print Agent...
cd /d "%PROJECT%"

:: Run hidden — no window visible
powershell -WindowStyle Hidden -Command "Start-Process '%NODE%' -ArgumentList 'print-agent\printAgent.js' -WorkingDirectory '%PROJECT%' -WindowStyle Hidden"

echo Print Agent started in background.
echo You can close this window.
timeout /t 3 >NUL
