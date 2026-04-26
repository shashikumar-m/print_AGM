@echo off
title PrintHub Server
cd /d "S:\project2\printer"
echo [%date% %time%] Starting PrintHub Server... >> logs\server.log
"S:\node.js\node.exe" server\server.js >> logs\server.log 2>&1
