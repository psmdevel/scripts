'--launch a 32-bit Explorer desktop from the 32-bit Secure Desktop

Dim oShell, bKey, sValue
Set oShell = WScript.CreateObject("Wscript.Shell")
sValue = oShell.RegRead("HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell")
If uCase(Trim(sValue)) <> "EXPLORER.EXE" Then
	oShell.RegWrite "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell", "explorer.exe", "REG_SZ"
	oShell.Run "m:\windows\system32\explorer.exe",0,False
	Wscript.Sleep 300
	oShell.RegWrite "HKLM\Software\Microsoft\Windows NT\CurrentVersion\WinLogon\Shell", "vaprgman.exe", "REG_SZ"
Else
	oShell.Run "m:\windows\system32\explorer.exe",0,False
End If
