'--description: count users

'--create objects
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set m_objShell=CreateObject("Wscript.Shell")

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
End If

'--overrides
m_boolEnableDebug=False
boolInvArg=False
boolHelp=false

'--init vars
m_strRecDelim=Chr(30)
m_strFieldDelim=Chr(31)

'--set log destinations
m_strLogDests="console"

'--get the target period from the command line 
strArg=""
If WScript.Arguments.Count > 0 Then
	Set objArgs = WScript.Arguments
	If Err.Number > 0 Then LogIt Err.Description
	strArg=Trim(objArgs(0))
End If

If strArg=vbNullString Then
	ShowUsage
	Wscript.Quit
End If

strTemp=Split(strArg,"-")
If uBound(strTemp) <> 1 Then
	ShowUsage
	Wscript.Quit
End If

m_strTargetYear=Trim(strTemp(0))
m_strTargetMonth=Trim(strTemp(1))
If m_strTargetYear=vbNullString Or m_strTargetMonth=vbNullString Then
	ShowUsage
	Wscript.Quit
End If

If Not IsNumeric(m_strTargetYear) Or Not IsNumeric(m_strTargetMonth) Then
	ShowUsage
	Wscript.Quit
End If
If m_strTargetYear < 2016 Or m_strTargetYear > 2020 Then
	ShowUsage
	Wscript.Quit
End If

If m_strTargetMonth < 1 Or m_strTargetMonth > 12 Then
	ShowUsage
	Wscript.Quit
End If
m_strTargetPeriod=m_strTargetYear & "-" & m_strTargetMonth

'--open an output file for the specified target period
m_strOutFile="countusers_" & Replace(m_strTargetPeriod,"-","_") & ".csv"
Set m_objOutFile=m_objFS.OpenTextFile("countusers_reports\" & m_strOutFile,2,True)

'--calculate the stop date
m_strFullTargetDateString=m_strTargetMonth & "-" & "01" & "-" & m_strTargetYear
m_strEndDate=DateAdd("m",1,m_strFullTargetDateString)
m_strEndMonth=Month(m_strEndDate)
If Len(m_strEndMonth) < 2 Then 
	m_strEndMonth="0" & m_strEndMonth
End If
m_strEndYear=Year(m_strEndDate)
m_strEndDateString=m_strEndYear & "-" & m_strEndMonth

LogIt "debug: m_strTargetPeriod=" & m_strTargetPeriod & ", m_strEndDateString=" & m_strEndDateString

'--set the control data connection string
m_strControlDataConnStr=SetControlDataConnStr
If m_strControlDataConnStr=vbNullString Then
	LogIt "could not establish a control string for the control_data database"
	Wscript.Quit
End If

'--get the total number of sites
LogIt "getting the total number of sites"
strSQL="select count(*) from sitetab;"
m_strRS=DbQuery(strSQL,m_strControlDataConnStr)
nTotalSites=m_strRS(0)

'--get the number of active sites
LogIt "getting the number of active sites"
strSQL="select count(*) from sitetab where status='active';"
m_strRS=DbQuery(strSQL,m_strControlDataConnStr)
nActiveSites=m_strRS(0)
LogIt "there are " & nTotalSites & " total sites, of which " & nActiveSites & " are active"

'--empty out the old user table
LogIt "debug: emptying the user table"
strSQL="delete from ecw_users;"
strRS=DbQuery(strSQL,m_strControlDataConnStr)

'--scan the active databases and accumulate information
LogIt "scanning all active databases..."
ScanActiveDBs

'--output the summary
OutputSummary

Sub ScanActiveDBs()

	'--get the details for the active sites
	strSQL="select siteid,db_cluster,keywords,reseller_id from sitetab where status='active' And siteid > '000' order by siteid;"
	'strSQL="select siteid,db_cluster,keywords,reseller_id from sitetab where siteid = '040';"
	strSitesRS=DbQuery(strSQL,m_strControlDataConnStr)
	LogIt "debug: uBound(strSitesRS)=" & uBound(strSitesRS)

	'--loop through the active site list
	LogIt "debug: looping through the site records"
	For nIndex=0 To uBound(strSitesRS)

		Wscript.StdOut.Write "."
	
		'--get a record
		strTemp=strSitesRS(nIndex)
		strSiteRec=Split(strTemp,m_strFieldDelim)
		
		'--extract the siteID and cluster name
		strSID=strSiteRec(0)
		strDbCluster=strSiteRec(1)
		strKeywords=strSiteRec(2)
		strResellerID=strSiteRec(3)
		LogIt "debug: site" & strSID & " is on cluster [" & strDbCluster & "]"
		
		'--make sure we got a cluster name
		If strDbCluster <> vbNullString Then
		
		'--establish the database name
			strDbName="mobiledoc_" & strSID
			
			'--set the connection string for this site
			strSiteConnStr=SetSiteConnStr(strDbCluster,strSID)
			LogIt "debug: strSiteConnStr=" & strSiteConnStr
			
			If strSiteConnStr <> vbNullString Then
			
				'--get the full user list for this site, including inactives, but not deleted records
				LogIt "getting user list for site" & strSID
				strSQL="select uid,ulname,ufname,usertype from users where usertype < 3 and status=0 and delflag=0 order by ulname,ufname;"
				m_strUserRS=DbQuery(strSQL,strSiteConnStr)
				
				'--loop through the user list for this site
				LogIt "debug: looping through user list for site" & strSID
				For nUserIndex=0 To uBound(m_strUserRS) 

					'--create an array for this user record
					strUserRec=Split(m_strUserRS(nUserIndex),m_strFieldDelim)
					
					'--extract the user id and other fields from the array
					If uBound(strUserRec)=3 Then
						strUid=strUserRec(0)
						strULName=Replace(strUserRec(1),"'","''")
						strUFName=Replace(strUserRec(2),"'","''")
						strUserType=strUserRec(3)
						LogIt "debug: strUid=" & strUid

						'--see if the user id logged in this month
						strLoginsRS=vbNullString
						LogIt "debug: checking if " & strUFname & " " & strULName & " logged in this month"
						strSQL="select serverlogintime,hostosusr from usrlogs where usrid='" & strUid & "' and serverlogintime >= '" & m_strTargetPeriod & "' and serverlogintime < '" & m_strEndDateString & "';"
						strLoginsRS=DbQuery(strSQL,strSiteConnStr)
						If strLoginsRS(0) <> vbNullString Then
						
							'--the user logged in this month, were any of them through RDS?
							LogIt "debug: user logged in this month" 
							strLogin_Type="other"
							LogIt "debug: uBound(strLoginsRS)=" & uBound(strLoginsRS)
							For nTempIndex=0 To uBound(strLoginsRS)
								strUsrLogRecArray=Split(strLoginsRS(nTempIndex),m_strFieldDelim)
								strServerLoginTime=strUsrLogRecArray(0)
								strHostOsUser=lCase(strUsrLogRecArray(1))
								LogIt "debug: strServerLoginTime=" & strServerLoginTime
								LogIt "debug: strHostOsUser=" & strHostOsUser
								If Instr(strHostOsUser,"mycharts") Then
									strLogin_Type="rds"
									Exit For
								End If
							Next
							LogIt "debug: login type was " & strLogin_Type 
							
							'--filter out some users by partial string
							boolFilterUser=False
							Dim strFilter
							Redim strFilter(14)
							strFilter(0)="support"
							strFilter(1)="eclinic"
							strFilter(2)="psm"
							strFilter(3)="goh"
							strFilter(4)="g1"
							strFilter(5)="ec3"
							strFilter(6)="admin"
							strFilter(7)="billing"
							strFilter(8)="curas"
							strFilter(9)="trust"
							strFilter(10)="cps"
							strFilter(11)="*"
							strFilter(12)="desk"
							strFilter(13)="front"
							strFilter(14)="coding"
							For nCounter=0 To uBound(strFilter)
								If Instr(lCase(strULName),strFilter(nCounter)) or Instr(lCase(strUFname),strFilter(nCounter)) Then
									boolFilterUser=True
									Exit For
								End If
							Next
							
							'--filter out some users by exact name
							Redim strFilter(0)
							strFilter(0)="rep"
							For nCounter=0 To uBound(strFilter)
								If lCase(strULName)=strFilter(nCounter) or lCase(strUFname)=strFilter(nCounter) Then
									boolFilterUser=True
									Exit For
								End If
							Next

							'--insert this user into the control data database
							If Not boolFilterUser Then
								LogIt "debug: inserting record into database" 
								strSQL="insert into ecw_users (sid,ulname,ufname,usertype,login_type) values ('" & _
									strSID & "','" & _
									strULName & "','" & _
									strUFName & "','" & _
									strUserType & "','" & _
									strLogin_Type & "');"
								LogIt "debug: " & strSQL
								strRS=DbQuery(strSQL,m_strControlDataConnStr)
							End if
						End If	
					Else
						LogIt "debug: unexpected number of fields in the record"
					End If
				
				Next
			Else
				LogIt "failed to connect to site" & strSID
			End If
			
		End If		
	
	Next

End Sub

Sub OutputSummary

	LogIt "generating summary file"

	'--set up the output headers in csv format
	strHeader1="""Site ID"",""Last"",""First"",""User Type"",""Login Type"""
	strBlankLine=""""","""","""","""","""""

	m_objOutFile.WriteLine strHeader1

	'--pull the records that were generated by the database sweep above 
	LogIt "debug: pulling recordset from summary sweep"
	strSQL="select sid,ulname,ufname,usertype,login_type from ecw_users order by sid,ulname,ufname;"
	strSummaryRS=DbQuery(strSQL,m_strControlDataConnStr)

	'--init some vars
	strOldSID=""
	boolFirstLoop=True
	dim strUsersAtSite()
	redim strUsersAtSite(0)

	'--loop through the record set
	LogIt "debug: looping through the recordset: uBound(strSummaryRS)=" & uBound(strSummaryRS)
	For nIndex=0 To uBound(strSummaryRS)
		
		'--get a record from the recordset
		strSummaryRec=Split(strSummaryRS(nIndex),m_strFieldDelim)
		strSID=strSummaryRec(0)
		strULName=strSummaryRec(1)
		strUFName=strSummaryRec(2)
		strUserType=Trim(strSummaryRec(3))
		strLogin_Type=strSummaryRec(4)

		'--if the SID has changed, update the totals
		If strSID <> strOldSID Then

			LogIt "debug: strSID changed from '" & strOldSID & "' to '" & strSID & "'"

			'--if this is not the first time through the loop, print a summary line for the previous site
			If Not boolFirstLoop Then
				strSubTotals="""" & strOldSID & """,""~ " & strPrimaryFacilityName & " (Subtotals) "","""","""","""","""",""" & intRdsUserCount & """"
				m_objOutFile.WriteLine strSubtotals
			Else
				boolFirstLoop=False
			End If
			strOldSID=strSID

			'--get the db cluster name
			strSQL="select db_cluster from sitetab where siteid='" & strSID & "';"
			strDbClusterRS=DbQuery(strSQL,m_strControlDataConnStr)
			strDbCluster=strDbClusterRS(0)

			If IsDbListening(strDbCluster,strSID)=True Then
				'--get the facilitiy name		
				strSQL="select name from edi_facilities where PrimaryFacility=1;"
				strSiteConnStr=SetSiteConnStr(strDbCluster,strSID)
				strPrimaryFacilityNameRS=DbQuery(strSQL,strSiteConnStr)
				strPrimaryFacilityName=strPrimaryFacilityNameRS(0)
			Else
				LogIt "failed to connect!"
				strPrimaryFacilityName="(failed to connect)"
			End If

			'--reset the per-site counts
			intRdsUserCount=0

		End If

		'--increment the site user count and total user count
		If strLogin_Type="rds" Then
			intRdsUserCount=intRdsUserCount+1
		End If
		intTotalUsers=intTotalUsers+1

		'--build a user line
		strLine=vbNullString
		strLine=strLine & """" & strSID & ""","
		strLine=strLine & """" & strPrimaryFacilityName & ""","
		strLine=strLine & """" & strULName & ""","
		strLine=strLine & """" & strUFName & ""","
		strLine=strLine & """" & strUserType & ""","
		strLine=strLine & """" & strLogin_Type & """" 

		'--output the user line
		m_objOutFile.WriteLine strLine
		
	Next

	'--output one last subtotals line for the last site
	strSubTotals="""" & strOldSID & """,""~ " & strPrimaryFacilityName & " (Subtotals) "","""","""","""","""",""" & intRdsUserCount & """"
	m_objOutFile.WriteLine strSubtotals

	'--output the totals line
	m_objOutFile.WriteLine strBlankLine
	strSubTotals=""""",""Totals"","""","""","""","""",""" & intTotalRdsLogins & """"
	m_objOutFile.WriteLine strSubtotals
	m_objOutFile.WriteLine strBlankLine
	Logit "done"

End Sub

'--END

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

Sub ShowUsage()
	LogIt "specify a reporting month in the format: YYYY-MM"
End Sub

Sub LogIt(strMsg)
	Logger strMsg,m_strLogDests
End Sub




