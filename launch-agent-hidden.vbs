Set oShell = CreateObject("WScript.Shell") 
oShell.CurrentDirectory = "S:\project2\printer\print-agent" 
oShell.Run Chr(34) & "S:\node.js\node.exe" & Chr(34) & " printAgent.js", 0, False 
