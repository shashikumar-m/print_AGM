@echo off
:: ============================================================
::  PrintHub - Register Windows Task Scheduler
::  Right-click this file -> "Run as administrator"
::  Run this ONCE on each printer PC
:: ============================================================

set TASKNAME=PrintHub-Agent
set XMLFILE=%~dp0printhub-task.xml

echo.
echo  ==========================================
echo   PrintHub Task Scheduler Setup
echo  ==========================================
echo.

:: Check XML file exists
if not exist "%XMLFILE%" (
    echo  ERROR: printhub-task.xml not found.
    echo  Make sure it is in the same folder as this file.
    pause
    exit /b 1
)

:: Remove old task silently
schtasks /delete /tn "%TASKNAME%" /f >nul 2>&1

:: Register using XML (most reliable method)
schtasks /create /tn "%TASKNAME%" /xml "%XMLFILE%" /f

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo  ERROR: Could not register task.
    echo  Make sure you right-clicked and chose "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo.
echo  Starting agent now...
schtasks /run /tn "%TASKNAME%"
timeout /t 2 /nobreak >nul

echo.
echo  ==========================================
echo   SUCCESS!
echo  ==========================================
echo.
echo  Print agent will now start automatically
echo  every time this PC boots - no login needed.
echo.
echo  Commands:
echo    Check : schtasks /query /tn "%TASKNAME%"
echo    Stop  : schtasks /end /tn "%TASKNAME%"
echo    Start : schtasks /run /tn "%TASKNAME%"
echo    Remove: schtasks /delete /tn "%TASKNAME%" /f
echo.
pause
