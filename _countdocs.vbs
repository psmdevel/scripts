'--description: count providers

'--create objects
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set m_objShell=CreateObject("Wscript.Shell")

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
End If

'--overrides
boolDebug=False
boolInvArg=False
boolHelp=false
m_boolEnableDebug=False

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
If m_strTargetYear < 2016 Or m_strTargetYear > 2099 Then
	ShowUsage
	Wscript.Quit
End If

If m_strTargetMonth < 1 Or m_strTargetMonth > 12 Then
	ShowUsage
	Wscript.Quit
End If
If m_strTargetMonth < 10 Then
	m_strTargetMonth="0" & m_strTargetMonth
End If
m_strTargetPeriod=m_strTargetYear & "-" & m_strTargetMonth

'--open an output file for the specified target period
m_strOutFile="countdocs_" & Replace(m_strTargetPeriod,"-","_") & ".csv"
Set m_objOutFile=m_objFS.OpenTextFile("countdocs_reports\" & m_strOutFile,2,True)

'--calculate the stop date
m_strFullTargetDateString=m_strTargetMonth & "-" & "01" & "-" & m_strTargetYear
m_strEndDate=DateAdd("m",1,m_strFullTargetDateString)
m_strEndMonth=Month(m_strEndDate)
If Len(m_strEndMonth) < 2 Then 
	m_strEndMonth="0" & m_strEndMonth
End If
m_strEndYear=Year(m_strEndDate)
m_strEndDateString=m_strEndYear & "-" & m_strEndMonth

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
LogIt "scanning all active databases..."

'--scan the active databases and accumulate information
ScanActiveDBs

'--output the summary
OutputSummary

Sub ScanActiveDBs()

	'--get the details for the active sites
	strSQL="select siteid,db_cluster,keywords,reseller_id from sitetab where status='active' And siteid > '000' order by siteid;"
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
			
				'--get the full provider list for this site, including inactives, but not deleted records
				LogIt "getting provider list for site" & strSID
				strSQL="select d.doctorid,d.licensekey,d.npi,u.uname,u.ulname,u.ufname,u.status from users u inner join doctors d where u.usertype=1 and u.delFlag=0 and u.uid=d.doctorid;"
				m_strProviderRS=DbQuery(strSQL,strSiteConnStr)
				
				'--loop through the provider list for this site
				LogIt "debug: looping through provider list for site" & strSID
				For nProvIndex=0 To uBound(m_strProviderRS) 

					'--process a provider record
					strProviderRec=Split(m_strProviderRS(nProvIndex),m_strFieldDelim)
					
					If uBound(strProviderRec)=6 Then
						strDoctorId=strProviderRec(0)
						strLicenseKey=strProviderRec(1)
						strNpi=strProviderRec(2)
						strUname=strProviderRec(3)
						strULName=Replace(strProviderRec(4),"'","''")
						strUFName=Replace(strProviderRec(5),"'","''")
						strStatus=strProviderRec(6)
						
						LogIt "debug: strDoctorId=" & strDoctorId

						'--see if the provider logged in this month
						strLoginRS=vbNullString
						LogIt "debug: checking if " & strUFname & " " & strULName & " logged in this month"
						strSQL="select serverlogintime from usrlogs where usrid='" & strDoctorID & "' and serverlogintime >= '" & m_strTargetPeriod & "' and serverlogintime < '" & m_strEndDateString & "' limit 1;"
						strLoginsRS=DbQuery(strSQL,strSiteConnStr)
						If strLoginsRS(0) <> vbNullString Then
							strLogged_In="yes"
						Else
							strLogged_In="no"
						End If
						
						LogIt "debug: strLogged_In=" & strLogged_In

						'--find this provider in the control data database
						LogIt "debug: finding provider " & strDoctorId & " in the control_data database"
						strSQL="select doctorid from providers where siteid=" & strSID & " and doctorid=" & strDoctorId & ";"
						strRS=DbQuery(strSQL,m_strControlDataConnStr)
						If strRS(0)=vbNullString Then
							LogIt "debug: provider not found, inserting"
							'--insert the record, set notes to 'added'
							strSQL="insert into providers (siteid,doctorid,npi,ulname,ufname,licensekey,logged_in,status,notes) values ('" & _
								strSID & "','" & _
								strDoctorId & "','" & _
								strNpi & "','" & _
								strULName & "','" & _
								strUFName & "','" & _
								strLicenseKey & "','" & _
								strLogged_In & "','" & _
								strStatus & "'," & _
								"'added');"
							LogIt "debug: " & strSQL
							strRS=DbQuery(strSQL,m_strControlDataConnStr)
							
						Else

							'--get the current values for this provider from the control_data database
							strSQL="select npi,ulname,ufname,logged_in,status from providers where siteid='" & strSID & "' and doctorid='" & strDoctorId & "' limit 1;"
							strRS=DbQuery(strSQL,m_strControlDataConnStr)
							
							LogIt "debug: found provider"
							LogIt "debug: strRS(0)=" & strRS(0)

							'--break it into fields
							strOldProviderRec=Split(strRS(0),m_strFieldDelim)
							strOldNpi=strOldProviderRec(0)
							strOldULName=strOldProviderRec(1)
							strOldUFName=strOldProviderRec(2)
							strOldLogged_In=strOldProviderRec(3)
							strOldStatus=strOldProviderRec(4)

							'--compare values
							boolChanged=False
							If strNpi <> strOldNpi Then boolChanged=True
							If strULName <> strOldULName Then boolChanged=True
							If strUFName <> strOldUFName Then boolChanged=True
							If strStatus <> strOldStatus Then boolChanged=True
							If strLogged_In <> strOldLogged_In Then boolChanged=True
							LogIt "debug: boolChanged=" & boolChanged

							'--update the record accordingly
							If boolChanged=false Then
								LogIt "debug: no change, setting notes field to empty"
								'--no change, set notes to empty for this provider record (if it is not already)
								strSQL="update providers set notes='' where siteid='" & strSID & "' and doctorid='" & strDoctorID & "';"
							Else
								'--update the record and set notes to 'changed'
								LogIt "debug: provider fields changed, updating control_data database"
								strSQL="update providers set siteid='" & strSID & "'," & _
									"doctorid='" & strDoctorID & "'," & _
									"npi='" & strNpi & "'," & _
									"ulname='" & strULName & "'," & _
									"ufname='" & strUFName & "'," & _
									"licensekey='" & strLicenseKey & "'," & _
									"logged_in='" & strLogged_In & "'," & _
									"notes='changed'," & _
									"status='" & strStatus & "' where siteid='" & strSID & "' and doctorid='" & strDoctorID & "';"
							End If
							LogIt "debug: strSQL=" & strSQL
							boolResult=DbExecute(strSQL,m_strControlDataConnStr)
							If boolResult=0 Then
								LogIt "debug: DbExecute returned 0 (success)"
							Else
								LogIt "debug: DbExecute returned <> 0 (fail)"
							End If

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
strHeader1=""""","""","""","""","""","""","""","""","""",""Provider"",""License"",""Logged In"",""Changed"",""Confident"""
strHeader2="""Site ID"",""Practice"",""Last"",""First"",""NPI"",""License Key"",""Logged In"",""Notes"",""Status"",""Count"",""Count"",""Count"",""Count"",""Count"""
strBlankLine=""""","""","""","""","""","""","""","""","""","""","""","""","""","""""

m_objOutFile.WriteLine strHeader1
m_objOutFile.WriteLine strHeader2

'--pull the records that were generated by the database sweep above 
LogIt "debug: pulling recordset from summwary sweep"
strSQL="select p.siteid,p.ulname,p.ufname,p.npi,if(p.licensekey <> '','yes','no'),p.logged_in,p.notes,p.status,s.keywords,s.reseller_id from providers p inner join sitetab s where p.siteid=s.siteid and s.status='active' order by p.siteid;"
strSummaryRS=DbQuery(strSQL,m_strControlDataConnStr)

'--init some vars
strOldSID=""
intTotalLicensed=0
intTotalLoggedIn=0
intTotalStatusZero=0
intTotalConfident=0
intTotalChanged=0
boolFirstLoop=True
dim strProvidersAtSite()
redim strProvidersAtSite(0)

'--loop through the record set
LogIt "debug: looping through the recordset"
For nIndex=0 To uBound(strSummaryRS)
	
	'--get a record from the recordset
	strSummaryRec=Split(strSummaryRS(nIndex),m_strFieldDelim)
	strSID=strSummaryRec(0)
	strULName=strSummaryRec(1)
	strUFName=strSummaryRec(2)
	strNpi=strSummaryRec(3)
	strLicenseKey=strSummaryRec(4)
	strLogged_In=strSummaryRec(5)
	strNotes=strSummaryRec(6)
	strStatus=Trim(strSummaryRec(7))
	strKeywords=strSummaryRec(8)
	strResellerID=strSummaryRec(9)	

	'--if the SID has changed, update the totals
	If strSID <> strOldSID Then

		LogIt "debug: strSID changed from '" & strOldSID & "' to '" & strSID & "'"

		'--if this is not the first time through the loop, print a summary line for the previous site
		If Not boolFirstLoop Then
			strSubTotals="""" & strOldSID & """,""~ " & strPrimaryFacilityName & " (Subtotals) "","""","""","""","""","""","""","""",""" & intProviderCount & """,""" & intLicensedCount & """,""" & intLoggedInCount & """,""" & intChangedCount & """,""" & intConfidentCount & """"
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
		intProviderCount=0
		intLicensedCount=0
		intLoggedInCount=0
		intChangedCount=0
		intStatusZeroCount=0
		intConfidentCount=0

	End If

	'--increment the site provider count and total provider count
	intProviderCount=intProviderCount+1
	intTotalProviders=intTotalProviders+1

	'--if this provider has a license key, increment the count of licensed providers for this site
	If strLicenseKey="yes" Then 
		intLicensedCount=intLicensedCount+1
		intTotalLicensed=intTotalLicensed+1
	End If

	'--if this provider logged in this month, increment the count of providers who logged in from this site
	If strLogged_In="yes" Then 
		intLoggedInCount=intLoggedInCount+1
		intTotalLoggedIn=intTotalLoggedIn+1
	End If

	'--if this provider has a status of 0 (active) then increment the count of active providers for this site
	If strStatus="0" Then
		intStatusZeroCount=intStatusZeroCount+1
		intTotalStatusZero=intTotalStatusZero+1
	End If

	'--check our confidence factors and increment the confidence count for this site
	If strNpi <> "" And strLicenseKey="yes" And strLogged_In="yes" And strStatus="0" Then 
		intConfidentCount=intConfidentCount+1
		intTotalConfident=intTotalConfident+1
	End If

	If strNotes <> "" Then 
		intChangedCount=IntChangedCount+1
		intTotalChanged=intTotalChanged+1
	End If

	'--build a provider line
	strLine=vbNullString
	strLine=strLine & """" & strSID & ""","
	strLine=strLine & """" & strPrimaryFacilityName & ""","
	strLine=strLine & """" & strULName & ""","
	strLine=strLine & """" & strUFName & ""","
	strLine=strLine & """" & strNpi & ""","
	strLine=strLine & """" & strLicenseKey & ""","
	strLine=strLine & """" & strLogged_In & ""","
	strLine=strLine & """" & strNotes & ""","
	strLine=strLine & """" & strStatus & ""","
	strLine=strLine & """"","
	strLine=strLine & """"","
	strLine=strLine & """"","
	strLine=strLine & """"""

	'--output the provider line
	m_objOutFile.WriteLine strLine
	
Next

'--output one last subtotals line for the last site
strSubTotals="""" & strOldSID & """,""~ " & strPrimaryFacilityName & " (Subtotals) "","""","""","""","""","""","""","""",""" & intProviderCount & """,""" & intLicensedCount & """,""" & intLoggedInCount & """,""" & intChangedCount & """,""" & intConfidentCount & """"
m_objOutFile.WriteLine strSubtotals


'--output the totals line
m_objOutFile.WriteLine strBlankLine
strSubTotals=""""",""Totals"","""","""","""","""","""","""","""",""" & intTotalProviders & """,""" & intTotalLicensed & """,""" & intTotalLoggedIn & """,""" & intTotalChanged & """,""" & intTotalConfident & """"
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




