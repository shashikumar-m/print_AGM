@echo off
:: ============================================================
::  PrintHub - Printer PC Setup
::  Run this ONCE on each printer PC
::  No need to edit any files manually
:: ============================================================

set PROJECT=%~dp0
set ENVFILE=%PROJECT%print-agent\.env
set NODE=S:\node.js\node.exe

cls
echo.
echo  ==========================================
echo   PrintHub - Printer PC Setup
echo   AGM Rural College
echo  ==========================================
echo.

:: Step 1 — Check Node.js
if not exist "%NODE%" (
    echo  ERROR: Node.js not found at %NODE%
    echo.
    echo  Please install Node.js from https://nodejs.org
    echo  or update the NODE path in this file.
    echo.
    pause
    exit /b 1
)
echo  [OK] Node.js found

:: Step 2 — Get Agent Key from admin
echo.
echo  Step 1: Get the Agent Key
echo  --------------------------
echo  1. Open the PrintHub admin panel in your browser
echo  2. Go to the "Printers" tab
echo  3. Find this printer and copy its Agent Key
echo.
set /p AGENT_KEY=  Paste the Agent Key here and press Enter: 

if "%AGENT_KEY%"=="" (
    echo  ERROR: Agent Key cannot be empty.
    pause
    exit /b 1
)

:: Step 3 — Get Printer Name
echo.
echo  Step 2: Enter the Windows Printer Name
echo  ----------------------------------------
echo  This is the exact name shown in Windows Settings > Printers
echo  Example: HP LaserJet 1020
echo            Brother DCP-T420W Printer
echo.
set /p PRINTER_NAME=  Enter printer name (or press Enter for Windows default): 

:: Step 4 — Write .env file
echo.
echo  Writing configuration...
(
echo SERVER_URL=https://print-agm.onrender.com
echo AGENT_KEY=%AGENT_KEY%
echo PRINTER_NAME=%PRINTER_NAME%
) > "%ENVFILE%"

echo  [OK] Configuration saved to print-agent\.env

:: Step 5 — Install npm packages if needed
if not exist "%PROJECT%print-agent\node_modules" (
    echo.
    echo  Installing dependencies...
    cd /d "%PROJECT%print-agent"
    "%NODE%" ..\node_modules\.bin\npm install >nul 2>&1
    call npm install >nul 2>&1
    echo  [OK] Dependencies installed
)

:: Step 6 — Register Task Scheduler (needs admin)
echo.
echo  Step 3: Register auto-start task
echo  ----------------------------------
echo  This will make the print agent start automatically
echo  every time this PC boots.
echo.
echo  You may see a UAC prompt - click YES to allow.
echo.

:: Write the task XML with correct paths
set XMLFILE=%PROJECT%printhub-task.xml
(
echo ^<?xml version="1.0" encoding="UTF-16"?^>
echo ^<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task"^>
echo   ^<RegistrationInfo^>
echo     ^<Description^>PrintHub Print Agent^</Description^>
echo   ^</RegistrationInfo^>
echo   ^<Triggers^>
echo     ^<BootTrigger^>^<Enabled^>true^</Enabled^>^</BootTrigger^>
echo   ^</Triggers^>
echo   ^<Principals^>
echo     ^<Principal id="Author"^>
echo       ^<UserId^>S-1-5-18^</UserId^>
echo       ^<RunLevel^>HighestAvailable^</RunLevel^>
echo     ^</Principal^>
echo   ^</Principals^>
echo   ^<Settings^>
echo     ^<MultipleInstancesPolicy^>IgnoreNew^</MultipleInstancesPolicy^>
echo     ^<DisallowStartIfOnBatteries^>false^</DisallowStartIfOnBatteries^>
echo     ^<StopIfGoingOnBatteries^>false^</StopIfGoingOnBatteries^>
echo     ^<ExecutionTimeLimit^>PT0S^</ExecutionTimeLimit^>
echo     ^<RestartOnFailure^>^<Interval^>PT1M^</Interval^>^<Count^>999^</Count^>^</RestartOnFailure^>
echo     ^<StartWhenAvailable^>true^</StartWhenAvailable^>
echo   ^</Settings^>
echo   ^<Actions^>
echo     ^<Exec^>
echo       ^<Command^>%NODE%^</Command^>
echo       ^<Arguments^>print-agent\printAgent.js^</Arguments^>
echo       ^<WorkingDirectory^>%PROJECT:~0,-1%^</WorkingDirectory^>
echo     ^</Exec^>
echo   ^</Actions^>
echo ^</Task^>
) > "%XMLFILE%"

:: Run schtasks as admin using runas
powershell -Command "Start-Process cmd -ArgumentList '/c schtasks /delete /tn PrintHub-Agent /f >nul 2>&1 & schtasks /create /tn PrintHub-Agent /xml \"%XMLFILE%\" /f && schtasks /run /tn PrintHub-Agent' -Verb RunAs -Wait"

echo.
echo  ==========================================
echo   Setup Complete!
echo  ==========================================
echo.
echo  The print agent is now:
echo   - Configured with your Agent Key
echo   - Set to start automatically at boot
echo   - Running right now in the background
echo.
echo  To verify: open Task Manager and look
echo  for "node.exe" in the processes list.
echo.
pause
