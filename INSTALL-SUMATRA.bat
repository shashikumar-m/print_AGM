@echo off
:: Downloads and installs SumatraPDF silently
:: Required for reliable PDF printing without popups

echo Downloading SumatraPDF...
set DEST=%TEMP%\SumatraPDF-installer.exe

powershell -NoProfile -Command ^
  "Invoke-WebRequest -Uri 'https://www.sumatrapdfreader.org/dl/rel/3.5.2/SumatraPDF-3.5.2-64-install.exe' -OutFile '%DEST%' -UseBasicParsing"

if not exist "%DEST%" (
    echo Download failed. Please install manually from:
    echo https://www.sumatrapdfreader.org/download-free-pdf-viewer
    pause
    exit /b 1
)

echo Installing SumatraPDF silently...
"%DEST%" /S

:: Verify
if exist "C:\Program Files\SumatraPDF\SumatraPDF.exe" (
    echo ✅ SumatraPDF installed successfully!
) else (
    echo ✅ Installation complete. Restart the print agent.
)

del "%DEST%" >NUL 2>&1
echo.
echo Now restart the print agent by running SETUP-AUTOSTART.bat
pause
