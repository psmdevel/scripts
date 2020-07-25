'On Error Resume Next

Sub ShowUsage
	Wscript.Echo "usage: tomcatsvc [--site:<id>]"
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
	Wscript.Echo "-- no valid siteID was provided"
	Wscript.Quit
End If 

'--pad SID as necessary
If Len(intSID)=1 Then intSID="00" & intSID
If Len(intSID)=2 Then intSID="0" & intSID

'--get the app cluster ID for this site
strRS=QueryControlData("select app_cluster_id from sitetab where siteid='" & intSID & "';")
intAppClustID=PopRecord(strRS)
If intAppClustID=vbNullSting Then
	Wscript.Echo "-- could not determine app cluster ID for site" & intSID & "."
	Wscript.Quit
End If

'--get the app servers assigned to the cluster ID
strRS=QueryControlData("select a1,a2 from app_clusters where id='" & intAppClustID & "';")
strRecord=PopRecord(strRS)
strAppServers=Split(strRecord,vbTab)
strTomcatA=strAppServers(0)
strTomcatB=strAppServers(1)
If strTomcatA=vbNullString or strTomcatB=vbNullString Then
	Wscript.Echo "-- one or both app servers is empty"
	Wscript.Quit
End If

'--get the ssh hostkeys
strHostKeyA=PopRecord(QueryControlData("select hostkey from ssh_hostkeys where hostname='" & strTomcatA & "';"))
strHostKeyB=PopRecord(QueryControlData("select hostkey from ssh_hostkeys where hostname='" & strTomcatB & "';"))
If strHostKeyA=vbNullString Or strHostKeyB=vbNullString Then
	Wscript.Echo "-- one or both ssh hostkeys is empty"
	Wscript.Quit
End If

'--update ssh hostkeys in the registry
Set objShell=CreateObject("Wscript.Shell")
Err.Clear
objShell.RegWrite "HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:" & strTomcatA, strHostKeyA, "REG_SZ"
If Err.Description <> vbNullString Then
	Wscript.Echo "-- error updating ssh hostkey for server " & strTomcatA & " to the registry."
	Wscript.Quit
End If
Err.Clear
objShell.RegWrite "HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:" & strTomcatB, strHostKeyB, "REG_SZ"
If Err.Description <> vbNullString Then
	Wscript.Echo "-- error updating ssh hostkey for server " & strTomcatB & " to the registry."
	Wscript.Quit
End If
Set objShell = Nothing

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
	Wscript.Echo "---------------------------------------------------"
	Wscript.Echo "NOTE: Stopping and starting tomcat is safe and will" 
	Wscript.Echo "      not cause downtime for the medical practice. "
	Wscript.Echo "---------------------------------------------------"
	Wscript.Echo
	Wscript.StdOut.Write "Select: "
	intCommand=""
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
	If intCommand < 10 Then
		Wscript.Echo
		Wscript.StdOut.Write "Clear the work folders? "
		strAnswer = lCase(Trim(lCase(Wscript.StdIn.ReadLine)))
		If strAnswer="y" Or strAnswer="yes" Then
			boolClear=True
		End If
	End If

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
			CheckTomcat 1,False
			CheckTomcat 2,False
		Case Else
			TimeToExit=True
	End Select
	Wscript.Echo
	If Not TimeToExit Then
		Wscript.StdOut.Write "Press ENTER to continue: "
		strAnswer=Wscript.StdIn.ReadLine
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
			strTriggers(12)="is stopped" & "|" & "exit"
			strTriggers(13)="setting this server's load balancer priority to 0" & "|" & vbNullString
			strTriggers(14)="load balancer will now divert new connections away from this server" & "|" & vbNullString
			strTriggers(15)="stopping" & "|" & vbNullString
			strTriggers(16)="active count administratively forced to 0" & "|" & vbNullString
			strTriggers(17)="active connection count reached 0" & "|" & vbNullString
			strTriggers(18)="maximum wait time exceeded" & "|" & vbNullString
			strTriggers(19)=vbNullString

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
			strTriggers(9)="CheckDbConnection succeeded" & "|" & "exit"
			strTriggers(10)="starting up" & "|" & vbNullString
			strTriggers(11)=vbNullString

		Case "status"

			strTriggers(0)="Last login" & "|" & "safe_tomcat --site=" & intSID & " --status " 
			strTriggers(1)="is running" & "|" & "exit"
			strTriggers(2)="is not running" & "|" & "exit"
			strTriggers(3)=vbNullString
		
	End Select
	
	'--connect to the linux box and send the command
	Set objShell=CreateObject("Wscript.Shell")
	strPlinkCmd="plink -i m:\scripts\sources\ts01_privkey.ppk root@" & strServer
	Set oExec=objShell.Exec(strPlinkCmd)

	'---loop through the lines of output from the command
	boolExit=False
	Do While Not boolExit

		'--get a line of output
		strLine = oExec.StdOut.ReadLine
		'Wscript.Echo strLine
			
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
				'Wscript.Echo "rx: " & strRx 
				'Wscript.Echo "tx: " & strTx
				boolTrFound=True
				Exit For
			End If
		Next

		'--if we found a trigger, send the response
		If Not oExec.StdOut.AtEndOfStream And boolTrFound Then
			oExec.StdIn.WriteLine strTx

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

Function QueryControlData(strSQL)
	Set objShell=CreateObject("Wscript.Shell")
	strRS=vbNullString
	strCmd="""M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s --skip-column-names"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strRecord=oExec.StdOut.ReadLine & vbCrLf
		strRS=strRS & strRecord
	Loop
	Set objShell=Nothing
	QueryControlData=strRS
End Function

Function PopRecord(strRS)
	intPos=Instr(strRS,vbCrLf)
	If intPos > 0 Then
		strRec=Left(strRS,intPos-1)
		strRS=Right(strRS,Len(strRS)-intPos)
	End If
	PopRecord=Replace(strRec,"\\","\")
End Function


