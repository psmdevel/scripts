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

'--get the list of apu servers
strSQL="select * from apu_servers;"
strApuServers=GetControlData(strSQL)

'--loop through the Apu servers looking for the sid
Do While strApuServers <> ""

	'--get a Apu server name
	strApuServer=PopRecord(strApuServers)

	'--check if a Apu subfolder exists on that server
	strFolder="\\" & strApuServer & "\c$\sites\" & strSID
	If objFS.FolderExists(strFolder) Then
		Exit Do
	Else
		strFolder=""
	End If

Loop

If strFolder <> "" Then
	Wscript.Echo "located apu folder: " & strFolder & "\tomcat6"
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
	strCmd="""m:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s -N"
	Set oExec=m_objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strRS=strRS & strLine & m_strRecDelim
	Loop
	GetControlData=strRS
End Function

