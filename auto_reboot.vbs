On Error Resume Next

'--instantiate the objects
Set objShell=CreateObject("Wscript.Shell")
Set objNet=CreateObject("Wscript.Network")
Set objFS=CreateObject("Scripting.FileSystemObject")

'--write a divider in the log file
LogIt "--------------------------------------------"

'--get my computer name
strServerName=lCase(objNet.ComputerName)
LogIt "my computer name is " & strServerName

'--get the names of the servers in this ts cluster
strSQL="select t1,t2 from ts_clusters where t1='" & strServerName & "' or t2='" & strServerName & "';"
strTsList=PopRecord(QueryControlData(strSQL))
strTsArray=Split(strTsList,vbTab)
strTs1=Trim(lCase(strTsArray(0)))
strTs2=Trim(lCase(strTsArray(1)))
LogIt "servers in my cluster are " & strTs1 & ", " & strTs2
	
'--establish my role
strLeadServer=""
If strTs1=strServerName Then
	strMyRole="lead"
Else
	strMyRole="follow"
End If
LogIt "my role is: " & strMyRole
If strMyRole="" Then
	LogIt "could not identify my role"
	LogIt "quitting"
	Wscript.Quit
End If

'--read the last reboot date from the appropriate location
If strMyRole="lead" Then
	strLastRebootFile="m:\scripts\sources\auto_reboot.dat"
Else
	strLastRebootFile="\\" & strTs1 & "\m$\scripts\sources\auto_reboot.dat"
End If 	
strLastRebootDate="10/23/1960 12:00 AM"
If objFS.FileExists(strLastRebootFile) Then
	LoGIt "last reboot file located at " & strLastRebootFile
	Err.Clear
	Set objRebootFile=objFS.OpenTextFile(strLastRebootFile,1,True)
	If Err.Number > 0 Then
		LogIt "error opening " & strLastRebootFile & ": " & Err.Description
	Else
		strLine=Trim(objRebootFile.ReadLine)
		If strLine <> "" Then 
			strLastRebootDate=strLine
		End If
	End If
	Set objRebootFile=Nothing
Else
	LogIt "last reboot file does not exist"
End If
If strLastRebootDate="10/23/1960 12:00 AM" Then
	LogIt "last reboot date defaulted to " & strLastRebootDate
Else
	LogIt "last reboot date was " & strLastRebootDate
End If

'--set the condition based on my role
booReboot=False
If strMyRole="lead" Then

	'--i am the leader, if a reboot has ever happened and it has not been at least 6 days since then, bail out
	intDateDiff=DateDiff("d",strLastRebootDate,Now())
	LogIt intDateDiff & " days since the lead server rebooted"
	If intDateDiff < 6 Then
		LogIt "quitting"
		Wscript.Quit
	End If

	'--if the time is right, set the reboot flag
	intWeekDay=WeekDay(Now())
	strWeekDayName=WeekDayName(intWeekDay)
	LogIt "today is " & strWeekDayName
	intHour=Hour(Now())
	Select Case intWeekDay
		Case vbFriday
			If intHour >= 22 Then
				boolReboot=True
			Else
				LogIt "it is too early in the day"
			End If
		Case vbSaturday
			If intHour <= 4 Or intHour >= 22 Then
				boolReboot=True
			Else
				LogIt "the current time is not during the reboot window"
			End If
		Case vbSunday
			If intHour <=4 Then
				boolReboot=True
			Else
				LogIt "the current time is not during the reboot window"
			End If
	End Select

Else

	'--i am the follower, so if the lead server rebooted 1 hour ago, follow suit
	intHourDiff=DateDiff("h",strLastRebootDate,Now())
	LogIt intHourDiff & " hours since the lead server rebooted"
	If intHourDiff=1 Then
		boolReboot=True
	End If

End If

'--if the reboot flag has not been set, then quit
If boolReboot=True Then
	LogIt "reboot is triggered"
Else
	LogIt "quitting"
	Wscript.Quit
End If

'--alert users of impending reboot
LogIt "warning users of upcoming reboot"
strCmd="m:\windows\system32\msg.exe * /SERVER:" & strServerName & " ""The server will be rebooted for maintenance in 3 minutes. Logoff now to avoid losing work."""
objShell.Run strCmd,0,False

'--sleep 3 minutes
Wscript.Sleep 180000

'--if I am lead, record current date and time in the last reboot file
If strMyRole="lead" Then
	If objFS.FileExists(strLastRebootFile) Then
		objFS.DeleteFile strLastRebootFile
	End If
	Err.Clear
	Set objRebootFile=objFS.OpenTextFile(strLastRebootFile,2,True)
	If Err.Number > 0 Then
		LogIt "error creating " & strLastRebootFile & ": " & Err.Description
	End If
	Err.Clear
	objRebootFile.WriteLine Now()
	If Err.Number > 0 Then
		LogIt "error writing to " & strLastRebootFile & ": " & Err.Description
	End If
	Set objRebootFile=Nothing
End If

'--reboot
LogIt "rebooting now!"
strCmd="shutdown /r /t 1 /c ""Weekly restart"" /d p:0:0"
objShell.Run strCmd,0,False
Set objShell=Nothing
Set objNet=Nothing
Set objFS=Nothing

'--done
Wscript.Quit

'#################################################
'#                                               #
'#               Functions                       #
'#                                               #
'#################################################

Function QueryControlData(strSQL)
	strRS=vbNullString
	strRecord=vbNullString
	strCmd="""M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s --skip-column-names"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strRecord=oExec.StdOut.ReadLine & vbCrLf
		strRS=strRS & strRecord
	Loop
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

Private Sub LogIt(strMessage)
	Set objLog=objFS.OpenTextFile("m:\scripts\logs\auto_reboot.log",8,True)
	objLog.WriteLine Now() & ": " & strMessage
	Set objLog=Nothing
End Sub