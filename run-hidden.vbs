' Launches run-bot-crossing.cmd with no console window and waits, so the
' Scheduled Task stays "Running" for as long as the server is up.
Dim shell, here
Set shell = CreateObject("WScript.Shell")
here = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
shell.Run "cmd /c """ & here & "run-bot-crossing.cmd""", 0, True
