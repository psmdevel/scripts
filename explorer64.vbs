'--launch a 64-bit Explorer desktop from the 32-bit Secure Desktop
Dim oShell, bKey, sValue
Set oShell = WScript.CreateObject("Wscript.Shell")
sValue = lCase(oShell.RegRead("HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell"))
If sValue <> "explorer.exe" Then
	oShell.RegWrite "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell", "explorer.exe", "REG_SZ"
	oShell.Run "m:\windows\explorer.exe",0,False
	Wscript.Sleep 300
	oShell.RegWrite "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell", "sdesktop.exe", "REG_SZ"
Else
	oShell.Run "m:\windows\explorer.exe",0,False
End If
