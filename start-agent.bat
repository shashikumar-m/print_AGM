@echo off
title PrintHub Print Agent
cd /d "S:\project2\printer"
echo [%date% %time%] Starting PrintHub Print Agent... >> logs\agent.log
"S:\node.js\node.exe" print-agent\printAgent.js >> logs\agent.log 2>&1
