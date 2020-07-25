'--create the shell object
Set objShell=CreateObject("Wscript.Shell")

'--get the command line argument if one was provided
If WScript.Arguments.Count = 1 Then
	Set objArgs = WScript.Arguments
	strService=Trim(objArgs(0))
Else
	Wscript.Quit
End If

'--restart the service
objShell.Run "net stop """ & strService & """",0,True
objShell.Run "net start """ & strService & """",0,True

