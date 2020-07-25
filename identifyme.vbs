Set WshShell = WScript.CreateObject("WScript.Shell")
Set WshNetwork = WScript.CreateObject("WScript.Network")
SessionID=WshShell.ExpandEnvironmentStrings("%SESSIONNAME%")
iPos=Instr(SessionID,"#")
SessionID=Right(SessionID,Len(SessionID)-iPos)
vMsg="You are user '" & WshNetwork.UserName & "' attached to server '" & WshNetwork.ComputerName & "'"
vMsg=vMsg & "  [Session ID: " & SessionID & "]"
BtnCode = WshShell.Popup(vMsg,, "Network Identification",0+64)