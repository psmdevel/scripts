'--description: audit patches

boolInvArg=False
boolHelp=false

'--patches to look for
Dim strPatchIDs(3)
strPatchIDs(0)="1435"
strPatchIDs(1)="1445"
strPatchIDs(2)="1477"

'--create objects
Set objFS=CreateObject("Scripting.FileSystemObject")
Set objShell=CreateObject("Wscript.Shell")

'--get the total number of sites
strSQL="select count(*) from sitetab;"
intTotalSites=PopRecord(GetControlData(strSQL))

'--get the number of active sites
strSQL="select count(*) from sitetab where status='active';"
intActiveSites=PopRecord(GetControlData(strSQL))

Wscript.Echo
Wscript.Echo "-- there are " & intTotalSites & " total sites, of which " & intActiveSites & " are active"

'--output the header line
strHeader="site_id,apu,keywords,version"
For iCount=0 To uBound(strPatchIDs)-1
	strHeader=strHeader & "," & strPatchIDs(iCount)
Next
Wscript.Echo strHeader

'--get the list of active sites
strSQL="select siteid,db_cluster,keywords from sitetab where status='active' And siteid > '000' order by siteid;"
strSitesRS=GetControlData(strSQL)

'--loop through the site list
Do While strSitesRS <> vbNullString

	'--get a record
	strSiteRec=Split(PopRecord(strSitesRS),vbTab)

	'--extract the siteID and cluster name
	strSID=strSiteRec(0)
	strDbCluster=strSiteRec(1)
	strKeywords=strSiteRec(2)

	'--if we got a db cluster, get the database name
	If strDbCluster <> vbNullString Then

		strDbName=GetDbName(strSID,strDbCluster)

		'--if we got a darabase name, query it
		If strDbName <> vbNullString Then

			'--get version
			strSQL="select value from itemkeys where name='clientversion';"
			strVersion=PopRecord(RunQuery(strSID,strDbCluster,strDbName,strSQL))

			'--get APUID
			strSQL="select value from itemkeys where name='autoupgradekey';"
			strAPU=PopRecord(RunQuery(strSID,strDbCluster,strDbName,strSQL))

			'--reset the line of output
			strOutput=strSID & "," & strAPU & "," & strKeywords & "," & strVersion

			'--reset the found flag
			boolFound=False

			'--loop through the patches we are looking for
			For iCount=0 To uBound(strPatchIDs)-1

				'--get the patch status
				strSQL="select status from patcheslist where ecwpatchid='" & strPatchIDs(iCount) & "';"
				strResult=RunQuery(strSID,strDbCluster,strDbName,strSQL)

				If strResult <> "" Then
					If Instr(strResult,"complete") > 0 Then
						strResult="complete"
					Else
						strResult="enabled"
					End If
				Else
					strResult="not_enabled"
				End If	
				

				'--build the output line
				Select Case strResult
					Case "complete"
						strOutput=strOutput & ",complete"
					Case "enabled"
						strOutput=strOutput & ",download"
					Case "not_enabled"
						strOutput=strOutput & ",not_enabled"
					Case Else
						strOutput=strOutput & ",unknown"
				End Select
			Next

			'--output the line
			Wscript.Echo strOutput

		End If

	End If

Loop


'--end

Function GetControlData(strSQL)
	Set objShell=CreateObject("Wscript.Shell")
	strRS=vbNullString
	strCmd="""C:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s -N"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strRS=strRS & strLine & vbCrLf
	Loop
	GetControlData=strRS
End Function

Function GetDbName(strSID,strDbCluster)
	strSQL="show databases like 'mobiledoc_" & strSID & "';"
	Set objShell=CreateObject("Wscript.Shell")
	strRS=vbNullString
	strCmd="""C:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -h" & strDbCluster & " -P5" & strSID & " -uroot -pzrt+Axj23 -e""" & strSQL & """ -s -N"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strRS=strRS & strLine
	Loop
	GetDbName=strRS
End Function

Function RunQuery(strSID,strDbCluster,strDbName,strQuery)
	Set objShell=CreateObject("Wscript.Shell")
	strLocalRS=vbNullString
	strCmd="""C:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -h" & strDbCluster & " -P5" & strSID & " -uroot -pzrt+Axj23 -s -N -D" & strDbName & " -e""" & strQuery & """"
	Set oExec=objShell.Exec(strCmd)
	Do While Not oExec.StdOut.AtEndOfStream 
		strLine=oExec.StdOut.ReadLine
		strLocalRS=strLocalRS & strLine & vbCrLf
	Loop
	RunQuery=strLocalRS
End Function

Function PopRecord(strRS)
	intLen=Len(strRS)
	If intLen > 1 Then
		intPos=Instr(strRS,vbCrLf)
		If intPos > 0 Then
			PopRecord=Left(strRS,intPos-1)
			strRS=Right(strRS,intLen-(intPos+1))
		Else
			PopRecord=strRS
			strRS=vbNullString
		End If
	Else
		PopRecord=strRS
		strRS=vbNullString
	End If
End Function
