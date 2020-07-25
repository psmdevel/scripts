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
	LogIt "usage: tomcatsvc [--site:<id>]"
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
				intSID=strRight
				If intSID <> vbNullString Then
					If Not IsNumeric(intSID) Then
						boolBadArg=True
						Exit For
					Else
						If intSID < 1 Or intSID > 999 Then
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
If intSID=vbNullString Then
	Set objNet=CreateObject("Wscript.Network")
	strUserName=lCase(objNet.UserName)
	If Len(strUserName) >= 7 Then
		If Left(strUserName,4)="site" Then
			intSID=Mid(strUserName,5,3)
		End If
	End If
End If

'--did we end up with a valid SID?
If intSID=vbNullString Then
	LogIt "no valid siteID was provided"
	Wscript.Quit
End If 

'--pad SID as necessary
If Len(intSID)=1 Then intSID="00" & intSID
If Len(intSID)=2 Then intSID="0" & intSID

'--get the app cluster ID for this site
strRS=DbQuery("select app_cluster_id from sitetab where siteid='" & intSID & "';",m_strControlDataConnStr)
intAppClustID=strRS(0)
If intAppClustID=vbNullSting Then
	LogIt "could not determine app cluster ID for site" & intSID & "."
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

TimeToExit=False
Do While Not TimeToExit
	Wscript.StdOut.WriteBlankLines(60)
	Wscript.Echo "---------------------------------------------------"
	Wscript.Echo "Safe tomcat service manager for: site" & intSID
	Wscript.Echo "---------------------------------------------------"
	Wscript.Echo
	Wscript.Echo "       1. start   TomcatA"
	Wscript.Echo "       2. stop    TomcatA"
	Wscript.Echo "       3. restart TomcatA"
	Wscript.Echo
	Wscript.Echo "       4. start   TomcatB"
	Wscript.Echo "       5. stop    TomcatB"
	Wscript.Echo "       6. restart TomcatB"
	Wscript.Echo
	Wscript.Echo "       7. restart (Both)"
	Wscript.Echo
	Wscript.Echo "       8. status"
	Wscript.Echo "       9. quit"
	Wscript.Echo
	Wscript.StdOut.Write "Enter number: "
	intCommand = Trim(lCase(Wscript.StdIn.ReadLine))
	If intCommand=vbNullString Then
		intCommand=99
	Else
		If Not IsNumeric(intCommand) Then
			intCommand=99
		End If
	End If

	'--set the flag to clear the work folders
	boolClear=False
	If intCommand < 8 Then
		Wscript.Echo
		Wscript.StdOut.Write "Clear the work folders? (Enter=Yes) "
		strAnswer = lCase(Trim(lCase(Wscript.StdIn.ReadLine)))
		If strAnswer="y" Or strAnswer="yes" Or strAnswer=vbNullString Then
			boolClear=True
		End If
	End If

	If intCommand < 8 Then
		strMsg="For customers with SP2 or higher, this will close user sessions and force them to re-enter their credentials. "
		strMsg=strMsg & "Have you confirmed with the practice that it is okay to do this?"
		intButton=objShell.Popup(strMsg,,"WARNING! WARNING! WARNING!",4)
	End If
	If intCommand >= 8 Or intButton=6 Then
		'--run the selected command
		Select Case intCommand 
			Case 1
				Wscript.Echo
				StartTomcat 1,boolClear
			Case 2
				Wscript.Echo
				StopTomcat 1,boolClear 
			Case 3
				Wscript.Echo
				RestartTomcat 1,boolClear
			Case 4			
				Wscript.Echo
				StartTomcat 2,boolClear
			Case 5			
				Wscript.Echo
				StopTomcat 2,boolClear
			Case 6
				Wscript.Echo
				RestartTomcat 2,boolClear
			Case 7
				Wscript.Echo
				RestartTomcat 1,boolClear
				Wscript.Echo
				RestartTomcat 2,boolClear
			Case 8
				Wscript.Echo
				Wscript.Echo "Checking TomcatA..."
				CheckTomcat 1,False
				Wscript.Echo
				Wscript.Echo "Checking TomcatB..."
				CheckTomcat 2,False
			Case 9
				TimeToExit=True
		End Select
		Wscript.Echo
		If Not TimeToExit And intCommand >= 1 And intCommand <=8 Then
			Wscript.StdOut.Write "Press ENTER to continue: "
			strAnswer=Wscript.StdIn.ReadLine
		End If
	End If
Loop
Wscript.Quit

Sub CheckTomcat(intServer,boolClear)	
	ControlTomcat intServer,"status",boolClear
End Sub

Sub StopTomcat(intServer,boolClear)	
	ControlTomcat intServer,"stop",boolClear
End Sub

Sub StartTomcat(intServer,boolClear)	
	ControlTomcat intServer,"start",boolClear
End Sub

Sub RestartTomcat(intServer,boolClear)	
	StopTomcat intServer,boolClear
	StartTomcat intServer,boolClear
End Sub
	
Sub ControlTomcat(intServer,strAction,boolClear)

	'--an array for storing the triggers
	Dim strTriggers(30)

	'--set the clear flag
	If boolClear Then
		strClear="--clear"
	Else
		strClear=vbNullString
	End If

	'--set the server and label
	Select Case intServer
		Case 1
			strServer=strTomcatA
			strLabel="TomcatA"
		case 2
			strServer=strTomcatB
			strLabel="TomcatB"
	End Select

	'--set the triggers
	Select Case strAction

		Case "stop"

			strTriggers(0)="Last login" & "|" & "safe_tomcat --site=" & intSID & " --stop " & strClear
			strTriggers(1)="clearing work folders" & "|" & vbNullString
			strTriggers(2)="did not stop in the time alotted" & "|" & "exit"
			strTriggers(3)="load balancing is not enabled for this server" & "|" & "exit"
			strTriggers(4)="could not determine the other app server names" & "|" & "exit"
			strTriggers(5)="could not determine the ip address of the standby app server" & "|" & "exit"
			strTriggers(6)="cannot be safely stopped because no other app servers are running" & "|" & "exit"
			strTriggers(7)="waiting for active connections to complete" & "|" & vbNullString
			strTriggers(8)="is already stopped, but whatever" & "|" & vbNullString
			strTriggers(9)="killing an orphaned java process" & "|" & vbNullString
			strTriggers(10)="load balancing is enabled for this site" & "|" & vbNullString
			strTriggers(11)="lvs is not enabled" & "|" & "exit"
			strTriggers(12)="is not running" & "|" & "exit"
			strTriggers(13)="setting this server's load balancer priority to 0" & "|" & vbNullString
			strTriggers(14)="load balancer will now divert new connections away from this server" & "|" & vbNullString
			strTriggers(15)="stopping" & "|" & vbNullString
			strTriggers(16)="active count administratively forced to 0" & "|" & vbNullString
			strTriggers(17)="active connection count reached 0" & "|" & vbNullString
			strTriggers(18)="maximum wait time exceeded" & "|" & vbNullString
			strTriggers(19)="(wait could exceed 5 minutes)" & "|" & vbNullString
			strTriggers(20)=vbNullString

		Case "start"

			strTriggers(0)="Last login" & "|" & "safe_tomcat --site=" & intSID & " --start " & strClear
			strTriggers(1)="is running" & "|" & vbNullString
			strTriggers(2)="did not start in the time alotted" & "|" & "exit"
			strTriggers(3)="is already running" & "|" & "exit"
			strTriggers(4)="waiting for communication socket to start listening" & "|" & vbNullString
			strTriggers(5)="clearing work folders" & "|" & vbNullString
			strTriggers(6)="load balancer will begin directing new connections to this server" & "|" & "exit"
			strTriggers(7)="no load balancer redirection rules to update" & "|" & "exit"
			strTriggers(8)="CheckDBConnection failed" & "|" & "exit"
			strTriggers(9)="CheckDbConnection succeeded" & "|" & vbNullString
			strTriggers(10)="starting up" & "|" & vbNullString
			strTriggers(11)=vbNullString

		Case "status"

			strTriggers(0)="Last login" & "|" & "safe_tomcat --site=" & intSID & " --status " 
			strTriggers(1)="is running" & "|" & "exit"
			strTriggers(2)="is not running" & "|" & "exit"
			strTriggers(3)=vbNullString
		
	End Select
	
	'--connect to the linux box and send the command
	strPlinkCmd="plink -i m:\scripts\sources\ts01_privkey.ppk root@" & strServer
	Set objExec=objShell.Exec(strPlinkCmd)

	'---loop through the lines of output from the command
	boolExit=False
	Do While Not boolExit

		'--get a line of output
		strLine = objExec.StdOut.ReadLine
			
		'--does the line match a trigger?
		boolTrFound=False
		For i=0 To uBound(strTriggers)-1
			If strTriggers(i)=vbNullString Then
				Exit For
			End If
			strRxTx=vbNullString
			strRxTx=Split(strTriggers(i),"|")
			strRx=strRxTx(0)
			strTx=strRxTx(1)
			If Instr(strLine,strRx) > 0 Then
				boolTrFound=True
				Exit For
			End If
		Next

		'--if we found a trigger, send the response
		If Not objExec.StdOut.AtEndOfStream And boolTrFound Then
			objExec.StdIn.WriteLine strTx

			'--report the trigger except for the initial login
			If strRx <> "Last login" Then
				Wscript.Echo strLabel & ": " & strRx
			End If

			'--if we sent "exit" then do so
			If strTx="exit" Then
				boolExit=True
			End If
		End if
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


