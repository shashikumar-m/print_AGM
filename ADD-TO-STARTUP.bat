@echo off
:: Adds START-PRINTING.bat to Windows Startup folder
:: so it runs automatically every time you log in.
:: Run this ONCE on each PC.

set BAT=%~dp0START-PRINTING.bat
set STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
set SHORTCUT=%STARTUP%\PrintHub.lnk

:: Create shortcut using VBScript (no PowerShell needed)
set VBS=%TEMP%\make_shortcut.vbs
echo Set s = CreateObject("WScript.Shell").CreateShortcut("%SHORTCUT%") > "%VBS%"
echo s.TargetPath = "%BAT%" >> "%VBS%"
echo s.WorkingDirectory = "%~dp0" >> "%VBS%"
echo s.WindowStyle = 1 >> "%VBS%"
echo s.Description = "PrintHub Print Agent" >> "%VBS%"
echo s.Save >> "%VBS%"
wscript "%VBS%"
del "%VBS%"

if exist "%SHORTCUT%" (
    echo.
    echo  Done! PrintHub will now start automatically
    echo  every time you log into Windows.
    echo.
    echo  Starting now...
    start "" "%BAT%"
) else (
    echo.
    echo  Could not create shortcut.
    echo  Just double-click START-PRINTING.bat manually each time.
    echo.
)
pause
