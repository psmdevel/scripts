'--init vars
m_strRecDelim=Chr(30)

'--create objects
Set objArgs=Wscript.Arguments
Set objShell=CreateObject("Wscript.Shell")
Set objFS=CreateObject("Scripting.FileSystemObject")

'--get the SID argument
If objArgs.Count > 0 Then
	strSID=objArgs(0)
Else
	Wscript.Echo "No SID specified."
End If

'--get the list of lab servers
strSQL="select * from lab_servers;"
strLabServers=GetControlData(strSQL)

'--loop through the lab servers looking for the sid
Do While strLabServers <> ""

	'--get a lab server name
	strLabServer=PopRecord(strLabServers)

	'--check if a lab subfolder exists on that server
	strFolder="\\" & strLabServer & "\c$\alley\site" & strSID
	If objFS.FolderExists(strFolder) Then
		Exit Do
	Else
		strFolder=""
	End If

Loop

If strFolder <> "" Then
	Wscript.Echo "located lab folder: "  & strFolder 
End If


Function PopRecord(ByRef strRS)
	intPos=Instr(strRS,m_strRecDelim)
	If intPos > 0 Then
		strRec=Left(strRS,intPos-1)
		strRS=Right(strRS,Len(strRS)-intPos)
	End If
	strRec=Replace(strRec,"\\","\")
	PopRecord=strRec
End Function

Function GetControlData(strSQL)
	Set m_objShell=CreateObject("Wscript.Shell")
	strRS=vbNullString
	strCmd="""M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s -N"
	Set oExec=m_objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strRS=strRS & strLine & m_strRecDelim
	Loop
	GetControlData=strRS
End Function

