@echo off
echo Stopping PrintHub Print Agent...
wmic process where "name='node.exe' and commandline like '%%printAgent%%'" delete >NUL 2>&1
echo Done.
timeout /t 2 >NUL
