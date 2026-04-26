@echo off
title PrintHub - Print Agent
color 0A
cls
echo.
echo  ==========================================
echo    PrintHub - AGM Rural College
echo    Print Agent
echo  ==========================================
echo.
echo  Keep this window open while printing.
echo  Close it to stop the print agent.
echo.
echo  Starting...
echo.

cd /d "%~dp0"
node print-agent\printAgent.js

echo.
echo  Agent stopped. Press any key to exit.
pause >nul
