'On Error Resume Next

'--process arguments
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

'--if an invalid argument was provided, show usage
If boolBadArg Then
	Wscript.Echo "-- invalid argument"
	ShowUsage
	Wscript.Quit
End If

'--update the ts_bindings table
strSQL="INSERT into ts_bindings(siteid,t1,t2,t3,t4) " & _
"VALUES('" & vSID & "'," & _
"'" & strTsArray(1) & "'," & _
"'" & strTsArray(2) & "'," & _
"'" & strTsArray(3) & "'," & _
"'" & strTsArray(4) & "');"
Wscript.Echo
QueryControlData(strSQL)


'--done
Wscript.Echo "--done!"
Wscript.Echo
Wscript.Quit

'#################################################
'#                                               #
'#               Functions                       #
'#                                               #
'#################################################

Function QueryControlData(strSQL)
	Set objShell=CreateObject("Wscript.Shell")
	strRS=vbNullString
	strRecord=vbNullString
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

Sub ShowUsage()
	Wscript.Echo
	Wscript.Echo "usage:" & vbTab & "newsite [required] [options]"
	Wscript.Echo
	Wscript.Echo vbTab & "Required:"
	Wscript.Echo vbTab 
	Wscript.Echo vbTab & "--desc:<description>"
	Wscript.Echo vbTab & "--reseller:<reseller>"
	Wscript.Echo vbTab & "--tz:<timezone>"
	Wscript.Echo
	Wscript.Echo vbTab & "Options:"
	Wscript.Echo vbTab 
	Wscript.Echo vbTab & "--site:<ID> (defaults to next available)"
	Wscript.Echo vbTab & "--dbcluster:<cluster_name"	
	Wscript.Echo vbTab & "--rptserver:<rptserver>"
	Wscript.Echo vbTab & "--usercount:<1-50> (defaults to 15)"
	Wscript.Echo vbTab & "--billable:<yes|no> (defaults to 'yes')"
	Wscript.Echo
End Sub

Function IsAlphaNumeric(String)
	IsAlphaNumeric=True
	For i=1 to Len(String)
		sChar=Mid(String,i,1)
		If Instr("ABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890_-'(),. ",Ucase(sChar)) < 1 Then
			IsAlphaNumeric=False
			Exit For
		End If
	Next
End Function

Function IsNumeric(String)
	IsNumeric=True
	For i=1 to Len(String)
		sChar=Mid(String,i,1)
		If Instr("01234567890",Ucase(sChar)) < 1 Then
			IsNumeric=False
			Exit For
		End If
	Next
End Function
