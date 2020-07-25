'On Error Resume Next

Sub ShowUsage
	Wscript.Echo "usage: setperms [--site:<id>]"
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
Wscript.Echo "---------------------------------------------------"
Wscript.Echo "Setting filesystem permissions" 
Wscript.Echo "---------------------------------------------------"
Wscript.Echo

StartTomcat 1
StartTomcat 2

Wscript.Echo
Wscript.StdOut.Write "Press ENTER to continue: "

Wscript.Quit

'--Functions

Sub SetPerms(intServer)

	'--an array for storing the triggers
	Dim strTriggers(30)

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
	strTriggers(0)="Last login" & "|" & "safe_tomcat --site=" & intSID & " --stop " & strClear
	strTriggers(1)="setting portal_data folder permissions" & "|" & vbNullString
	strTriggers(2)="setting tomcat folder permissions" & "|" & vbNullString
	strTriggers(3)="setting home folder permissions" & "|" & vbNullString
	strTriggers(4)="~: done" & "|" & "exit"
	strTriggers(5)="~: done" & "|" & "exit"
	strTriggers(5)=vbNullString

	
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


