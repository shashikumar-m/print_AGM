@echo off
setlocal

set PROJECT=S:\project2\printer
set NODE=S:\node.js\node.exe
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set LAUNCHER=%PROJECT%\launch-agent-hidden.vbs
set SHORTCUT=%STARTUP%\PrintHub-Agent.lnk

echo.
echo ============================================
echo   PrintHub Auto-Start Setup
echo ============================================
echo.

:: Check node exists
if not exist "%NODE%" (
    echo ERROR: node.exe not found at %NODE%
    echo Edit this file and fix the NODE path.
    pause
    exit /b 1
)

:: Step 1 — Write the VBScript launcher (runs node with no window)
echo Set oShell = CreateObject("WScript.Shell") > "%LAUNCHER%"
echo oShell.CurrentDirectory = "%PROJECT%\print-agent" >> "%LAUNCHER%"
echo oShell.Run Chr(34) ^& "%NODE%" ^& Chr(34) ^& " printAgent.js", 0, False >> "%LAUNCHER%"

echo Created: %LAUNCHER%

:: Step 2 — Write a helper VBScript that creates the shortcut
set MKSHORTCUT=%TEMP%\mkshortcut.vbs
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%MKSHORTCUT%"
echo Set oLink = oWS.CreateShortcut("%SHORTCUT%") >> "%MKSHORTCUT%"
echo oLink.TargetPath = "wscript.exe" >> "%MKSHORTCUT%"
echo oLink.Arguments = Chr(34) ^& "%LAUNCHER%" ^& Chr(34) >> "%MKSHORTCUT%"
echo oLink.WorkingDirectory = "%PROJECT%\print-agent" >> "%MKSHORTCUT%"
echo oLink.Description = "PrintHub Print Agent" >> "%MKSHORTCUT%"
echo oLink.Save >> "%MKSHORTCUT%"

wscript.exe "%MKSHORTCUT%"
del "%MKSHORTCUT%" >NUL 2>&1

:: Check if shortcut was created
if exist "%SHORTCUT%" (
    echo Created: %SHORTCUT%
    echo.
    echo Starting agent now...
    wscript.exe "%LAUNCHER%"
    timeout /t 2 /nobreak >NUL
    echo.
    echo ============================================
    echo   SUCCESS!
    echo ============================================
    echo.
    echo  Print agent is now running in background.
    echo  It will auto-start at every Windows login.
    echo  No terminal or VS Code needed.
    echo.
    echo  To verify: Task Manager - look for node.exe
    echo  To stop:   double-click STOP-AGENT.bat
    echo.
) else (
    echo.
    echo ERROR: Could not create startup shortcut.
    echo Try right-clicking this file and choosing
    echo "Run as Administrator"
    echo.
)

pause
endlocal
