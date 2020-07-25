'--purpose: maps a drive letter to an app server
'--arguments: intTomcatNum, [strUserName]

'--create some objects
Set objNet = WScript.CreateObject("WScript.Network")
Set objShell = Wscript.CreateObject("Wscript.Shell")
Set objFS = Wscript.CreateObject("Scripting.FileSystemObject")

'--get the command line arguments
Set objArgs = WScript.Arguments
If objArgs.Count > 0 Then
  	intTomcatNum=objArgs(0)
	If objArgs.Count > 1 Then
		strUserName=objArgs(1)
	Else
		strUserName = lCase(objNet.UserName)

	End If
Else
	Wscript.Echo "Not enough arguments."
	Wscript.Quit
End If

'--get the siteID from the user name
If left(strUserName,4)="site" And Len(strUserName) >= 7 Then
	strSID=Mid(strUserName,5,3)
Else
	Wscript.Echo "Unable to determine the site ID."
	Wscript.Quit
End if

'--validate args
If Not isNumeric(intTomcatNum) Or Not IsNumeric(strSID) Then
	Wscript.Echo "Invalid arguments."
	Wscript.Quit
Else
	If intTomcatNum < 1 Or intTomcatNum > 2 Then
		Wscript.Echo "Invalid tomcat instance number."
		Wscript.Quit
	End If
End If

'--get app cluster id
strSQL="select app_cluster_id from sitetab where siteid='" & strSID & "';"
strAppClustID=QueryControlData(strSQL)
strAppClustID=Replace(strAppClustID,vbCrLf,"")

'--get the app servers asssigned to the app cluster
strSQL="select a1,a2 from app_clusters where id='" & strAppClustID & "';"
strRS=QueryControlData(strSQL)
strRS=Replace(strRS,vbCrLf,"")
strAppServers=Split(strRS,vbTab)

'--make sure the app server entries are not empty
If uBound(strAppServers) < 1 Then
	Wscript.Echo "No application servers assigned to this site."
	Wscript.Quit
Else
	If strAppServers(0)=vbNullString Or strAppServers(1)=vbNullString Then
		Wscript.Echo "An application server entry is blank or null."
		Wscript.Quit
	End If	
End If

'--map a drive to the requested tomcat instance
boolDriveMapped=False
Select Case intTomcatNum
	Case 1
		Set oDrives = objNet.EnumNetworkDrives
		For i = 0 to oDrives.Count - 1 Step 2
			If Instr(oDrives.Item(i),"F:") Then
				boolDriveMapped=True
			End If
		Next
		If Not boolDriveMapped Then
			objNet.MapNetWorkDrive "F:","\\" & strAppServers(0) & "\site" & strSID
		End If
		objShell.Run """M:\Program Files (x86)\SaaSExplorer\SaaSExplorer.exe"" f:\"
	Case 2
		Set oDrives = objNet.EnumNetworkDrives
		For i = 0 to oDrives.Count - 1 Step 2
			If Instr(oDrives.Item(i),"G:") Then
				boolDriveMapped=True
			End If
		Next
		If Not boolDriveMapped Then
			objNet.MapNetWorkDrive "G:","\\" & strAppServers(1) & "\site" & strSID
		End If
		objShell.Run """M:\Program Files (x86)\SaaSExplorer\SaaSExplorer.exe"" g:\"
End Select

Function QueryControlData(strSQL)
	'--get the path to mysql
	If objFS.FileExists("M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe") Then
		strProgFilesDir="M:\Program Files"
	Else
		If objFS.FileExits("M:\Program Files (x86)\MySQL\MySQL Server 5.1\bin\mysql.exe") Then
			strProgFilesDir="M:\Program Files (x86)"
		Else
			Wscript.Echo "Could not find database executable."
		End If
	End if
	strRS=vbNullString
	strCmd="""" & strProgFilesDir & "\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hdbclust11 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s -N"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strRS=strRS & strLine & vbCrLf
	Loop
	QueryControlData=strRS
End Function