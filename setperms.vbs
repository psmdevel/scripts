'On Error Resume Next

'--create the objects
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set objShell=CreateObject("Wscript.Shell")

'--toggle debug
m_boolEnableDebug=False

'--set the logging destinations (console, log, event, use + to combine)
m_strLogDests="console"

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
End If

'--set the control data connection string
m_strControlDataConnStr=SetControlDataConnStr()

Sub ShowUsage
	LogIt "usage: setperms [--site:<id>]"
End Sub

'--process command line arguments
Set objArgs=Wscript.Arguments
For intCount=0 To objArgs.Count - 1
	strArg=objArgs(intCount)
	intPos=Instr(strArg,":")
	If intPos > 0 Then 
		strLeft=Trim(Left(strArg,intPos-1))
		strRight=Trim(Right(strArg,Len(strArg)-intPos))
		Select Case strLeft
			Case "--site"
				strSID=strRight
				If strSID <> vbNullString Then
					If Not IsNumeric(strSID) Then
						boolBadArg=True
						Exit For
					Else
						If strSID < 1 Or strSID > 999 Then
							boolBadArg=True
							Exit For
						End if
					End If
				Else
					boolBadArg=True
					Exit For
				End If
			Case Else
				boolBadArg=True
				Exit For
		End Select
	Else
		boolBadArg=True
	End If
Next
If boolBadArg Then
	ShowUsage
	Wscript.Quit
End If

'--if no site ID was provided, get the logged on username
If strSID=vbNullString Then
	Set objNet=CreateObject("Wscript.Network")
	strUserName=lCase(objNet.UserName)
	If Len(strUserName) >= 7 Then
		If Left(strUserName,4)="site" Then
			strSID=Mid(strUserName,5,3)
		End If
	End If
End If

'--did we end up with a valid SID?
If strSID=vbNullString Then
	LogIt "no valid siteID was provided"
	Wscript.Quit
End If 

'--pad SID as necessary
If Len(strSID)=1 Then strSID="00" & strSID
If Len(strSID)=2 Then strSID="0" & strSID

'--get the app cluster ID for this site
strRS=DbQuery("select app_cluster_id from sitetab where siteid='" & strSID & "';",m_strControlDataConnStr)
intAppClustID=strRS(0)
If intAppClustID=vbNullSting Then
	LogIt "could not determine app cluster ID for site" & strSID & "."
	Wscript.Quit
End If

'--get the app servers assigned to the cluster ID
strRS=DbQuery("select a1,a2 from app_clusters where id='" & intAppClustID & "';",m_strControlDataConnStr)
strAppServers=Split(strRS(0),g_strFieldDelim)
strTomcatA=strAppServers(0)
strTomcatB=strAppServers(1)
If strTomcatA=vbNullString or strTomcatB=vbNullString Then
	LogIt "one or both app servers is empty"
	Wscript.Quit
End If

'--get the ssh hostkeys
strSQL="select hostkey from ssh_hostkeys where hostname='" & strTomcatA & "';"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strHostKeyA=strRS(0)
strSQL="select hostkey from ssh_hostkeys where hostname='" & strTomcatB & "';"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strHostKeyB=strRS(0)
If strHostKeyA=vbNullString Or strHostKeyB=vbNullString Then
	LogIt "one or both ssh hostkeys is empty"
	Wscript.Quit
End If

'--update ssh hostkeys in the registry
Err.Clear
objShell.RegWrite "HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:" & strTomcatA, strHostKeyA, "REG_SZ"
If Err.Description <> vbNullString Then
	LogIt "error updating ssh hostkey for server " & strTomcatA & " to the registry."
	Wscript.Quit
End If
Err.Clear
objShell.RegWrite "HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:" & strTomcatB, strHostKeyB, "REG_SZ"
If Err.Description <> vbNullString Then
	LogIt "error updating ssh hostkey for server " & strTomcatB & " to the registry."
	Wscript.Quit
End If

'--get confirmation
Wscript.StdOut.Write "Reset tomcat server permisisons for site" & strSID & " (Y/N)? "
strAnswer=Wscript.StdIn.ReadLine
If lCase(strAnswer) <> "y" and lCase(strAnswer) <> "yes" Then
	Wscript.Echo
	Wscript.Echo "   aborted."
	Wscript.Quit
End If

'--run the command
Wscript.Echo 
SetPerms strTomcatA
Wscript.Echo 
SetPerms strTomcatB
Wscript.Echo

'--finish
Wscript.StdOut.Write "Complete. Press ENTER to continue: "
strAnswer=Wscript.StdIn.ReadLine
Wscript.Quit

Sub SetPerms(strServer)

	LogIt "contacting server " & strServer

	'--connect to the linux box and send the command
	strPlinkCmd="plink -i m:\scripts\sources\ts01_privkey.ppk root@" & strServer
	Set objExec=objShell.Exec(strPlinkCmd)

	'---loop through the lines of output from the command
	Do While Not objExec.StdOut.AtEndOfStream

		'--get a line of output
		strLine = objExec.StdOut.ReadLine
		
		'--display it if appropriate
		If Left(strLine,2)="~:" Then
			Wscript.Echo strLine
		End If
			
		'--if we got logged in, send the command
		If Instr(strLine,"Last login") > 0 Then
			boolShowLines=True
			strCmd="/scripts/setperms --site=" & strSID & ";exit"
			objExec.StdIn.WriteLine strCmd
		End If
	Loop

End Sub

'--LoadLibrary
Function LoadLibrary
	'On Error Resume Next
	Dim nError
	Err.Clear
	Set objFile=m_objFS.OpenTextFile("\scripts\_functions.vbs",1)
	nError=nError+Err.Number
	strFileContents=objFile.ReadAll
	nError=nError+Err.Number
	ExecuteGlobal strFileContents
	nError=nError+Err.Number
	Set objFile=Nothing
	'On Error Goto 0
	LoadLibrary=nError
End Function

Sub LogIt(strMsg)
	Logger strMsg,m_strLogDests
End Sub


