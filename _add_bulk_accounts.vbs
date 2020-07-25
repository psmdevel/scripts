'On Error Resume Next

Const ADS_SCOPE_SUBTREE = 2
Const ADS_PROPERTY_UPDATE = 2
Const ADS_PROPERTY_APPEND = 3 
Const ADS_GROUP_TYPE_GLOBAL_GROUP = &h2
Const ADS_GROUP_TYPE_SECURITY_ENABLED = &h80000000
Const ADS_ACETYPE_ACCESS_DENIED_OBJECT = &H6
Const ADS_ACEFLAG_OBJECT_TYPE_PRESENT = &H1
Const CHANGE_PASSWORD_GUID = "{ab721a53-1e2f-11d0-9819-00aa0040529b}"
Const ADS_RIGHT_DS_CONTROL_ACCESS = &H100
Const ADS_UF_DONT_EXPIRE_PASSWD = &h10000
Const FILE_SHARE = 0
Const MAXIMUM_CONNECTIONS = 25

'--create main objects
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set m_objShell=CreateObject("Wscript.Shell")
Set m_objArgs=Wscript.Arguments

'--create ADS connection objects
Set m_objDomain = GetObject("LDAP://dc=mycharts,dc=md")
Set m_objConnection = CreateObject("ADODB.Connection")
Set m_objCommand =   CreateObject("ADODB.Command")
m_objConnection.Provider = "ADsDSOObject"
m_objConnection.Open "Active Directory Provider"

'--set vars
m_boolProceed=False
m_boolEnableDebug=False
m_strAccountList=""

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
End If

'--set log destinations
m_strLogDests="console"

'--process arguments
For intCount=0 To m_objArgs.Count-1

	boolInvalidArg=True
	strLeft=""
	strRight=""
	
	'--a do-loop workaround for vbscript's missing "continue" statement
	Do

		'--get an argument string
		strArg=m_objArgs(intCount)

		'--split it into left and right if appropriate
		strArgArray=Split(strArg,":")
		
		'--make sure there are no more than 2 parts
		If uBound(strArgArray) > 1 Then
			Exit Do
		End If
		
		'--get the left part (which may be the only part)
		strLeft=strArgArray(0)
		
		'--get the right part if there is one
		If uBound(strArgArray)=1 Then
			strRight=strArgArray(1)
			boolInvalidArg=False
		End If
		
		'--site
		If strLeft="--site" Or strLeft="-s" Then
			m_strSID=strRight
			boolInvalidArg=False
		End If
		
		'--expiredays
		If strLeft="--expiredays" Or strLeft="-d" Then
			m_strExpireDays=strRight
			boolInvalidArg=False
		End If
		
		'--proceed
		If strLeft="--proceed" or strleft="-y" or strLeft="--yes" Or strLeft="-b" Or strLeft="--batch" Then	
			m_boolProceed=True
			boolInvalidArg=False
		End If
		
		If boolInvalidArg Then
			Exit Do
		End If
		
		'LogIt "strLeft=" & strLeft & ", strRight=" & strRight
		
	Loop While False

Next

'--sanity checks
If Len(m_strSID) <> 3 Then
	LogIt "must enter a site id in format --site:###"
	Wscript.Quit
End If
If Not IsNumeric(m_strSID) Then
	LogIt "site id is not numeric"
	Wscript.Quit
End If

'--set the control data connection string
m_strControlDataConnStr=SetControlDataConnStr
If m_strControlDataConnStr=vbNullString Then
	LogIt "could not establish a control string for the control_data database"
	Wscript.Quit
End If

'--verify that the site is active
strSQL="select siteid from sitetab where siteid='" & m_strSID & "';"
m_strRS=DbQuery(strSQL,m_strControlDataConnStr)
If m_strRS(0) <> m_strSID Then
	LogIt "site" & m_strSID & " is inactive or does not exist"
	Wscript.Quit
End If

'--get the db cluster name
strSQL="select db_cluster from sitetab where siteid='" & m_strSID & "';"
m_strRS=DbQuery(strSQL,m_strControlDataConnStr)
If m_strRS(0)= "" Then
	LogIt "could not determine db cluster name"
	Wscript.Quit
Else
	m_strDbCluster=m_strRS(0)
End If

'--set the connection string for this site
m_strSiteConnStr=SetSiteConnStr(m_strDbCluster,m_strSID)
LogIt "debug: m_strSiteConnStr=" & m_strSiteConnStr
If m_strSiteConnStr="" Then
	LogIt "error connecting to database for site" & m_strSID & "; aborting"
	Wscript.Quit
End If

'--set a start date 30 days ago
dtStartDate=DateAdd("d",-30,Now())
strStartYear=Year(dtStartDate)
strStartMonth=Month(dtStartDate):If Len(strStartMonth)=1 Then strStartMonth="0" & strStartMonth
strStartDay=Day(dtStartDate):If Len(strStartDay)=1 Then strStartDay="0" & strStartDay
strStartDate=strStartYear & "-" & strStartMonth & "-" & strStartDay

'--set an expiration date 30 days from now
dtExpirationDate=DateAdd("d",30,Now())
strExpirationYear=Year(dtExpirationDate)
strExpirationMonth=Month(dtExpirationDate):If Len(strExpirationMonth)=1 Then strExpirationMonth="0" & strExpirationMonth
strExpirationDay=Day(dtExpirationDate):If Len(strExpirationDay)=1 Then strExpirationDay="0" & strExpirationDay
m_strExpirationDate=strExpirationMonth & "/" & strExpirationDay & "/" & strExpirationYear

'--get the site's Windows password
strSQL="select win_pwd from sitetab where siteid='" & m_strSID & "';"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
m_strSiteWinPwd=strRS(0)
If m_strSiteWinPwd="" Then
	LogIt "unable to obtain site windows password; aborting"
	Wscript.Quit
End If	

'--get the recordset of users who have logged in through RDP in the past 30 days
strSQL="select distinct u.ulname,u.ufname from usrlogs l inner join users u where l.hostosusr like 'mycharts%' and l.usrid=u.uid and l.hostlogintime > '" & strStartDate & "' and u.delflag=0 and u.uname not like '%support%' and u.ulname not like '%support%' and u.uname not like '%billing%' and u.ulname not like '%billing%' order by ulname,ufname,uname;"
m_strRS=DbQuery(strSQL,m_strSiteConnStr)
If m_strRS(0)= vbNullString Then
	LogIt "no users logged in through RDP in the past 30 days"
	Wscript.Quit
End If

'--select records
Dim m_strRemovedUsers()
Redim m_strRemovedUsers(0)
m_nDisplayFirstRec=0
m_nDisplayLastRec=0
m_boolRecordSelectionComplete=False
Do While Not m_boolRecordSelectionComplete

	'--build the user account array
	'Wscript.Echo "calling DisplayRecordSet with m_nDisplayFirstRec=" & m_nDisplayFirstRec
	DisplayRecordSet m_nDisplayFirstRec
	
	'--get valid input
	Do While True
		Wscript.StdOut.Write "[N]ext Page, [P]revious Page, [R]efresh, [F]inish, [Q]uit, or # to Remove: "
		strAnswer=lCase(Trim(Wscript.StdIn.ReadLine))
		Select Case strAnswer
			Case "r"
				Exit Do
			Case "f"
				Wscript.StdOut.Write "Record selection complete? [Y/N]: "
				strAnswer=lCase(Trim(Wscript.StdIn.ReadLine))
				If strAnswer="y" Then
					m_boolRecordSelectionComplete=True
					Exit Do
				End If
			Case "n"
				If m_nDisplayLastRec+1 < uBound(m_strRS) Then
					m_nDisplayFirstRec=m_nDisplayLastRec+1
				End If
				Exit Do
			Case "p"
				m_nDisplayFirstRec=m_nDisplayFirstRec-51
				If m_nDisplayFirstRec < 0 Then
					m_nDisplayFirstRec=0
				End If
				Exit Do
			Case "q"
				Wscript.Quit
			Case Else
				If IsNumeric(strAnswer) Then
				
					nAnswer=CInt(strAnswer)
				
					'--make sure the request is a whole number
					If CDbl(strAnswer) <> nAnswer Then
						Wscript.Echo "Whole numbers only, please."
					End If
					
					'--make sure the request is in range
					If nAnswer < m_nDisplayFirstRec Or nAnswer > m_nDisplayLastRec Then
						Wscript.Echo "Request is out of range."
					End if
					
					'--verify removal from array
					m_strRecArray=Split(m_strRS(nAnswer),g_strFieldDelim)
					m_strULName=m_strRecArray(0)
					m_strUFName=m_strRecArray(1)					
					Wscript.StdOut.Write "Remove '" & m_strULName & ", " & m_strUFName & "'? [Y/N]: "
					strAnswer=lCase(Trim(Wscript.StdIn.ReadLine))
					
					If strAnswer="y" Then
						RemoveRecord nAnswer
						
						'--add it to the list of removed users for later display
						If m_strRemovedUsers(0)="" Then
							m_strRemovedUsers(0)=m_strULName & "," & m_strUFName
						Else
							Redim Preserve m_strRemovedUsers(uBound(m_strRemovedUsers)+1)
							m_strRemovedUsers(uBound(m_strRemovedUsers))=m_strULName & "," & m_strUFName
						End If
						
						Exit Do
					End If

				End If

		End Select
	Loop
	
Loop

'--confirm request for creation of new users
Wscript.Echo
Wscript.Echo "            site: " & m_strSID 
Wscript.Echo "    win_password: " & m_strSiteWinPwd
Wscript.Echo
Wscript.Echo "-- site" & m_strSID & " removed users --"
For nCounter=0 To uBound(m_strRemovedUsers)
	Wscript.Echo m_strRemovedUsers(nCounter)
Next
Wscript.Echo
Wscript.StdOut.Write "Respond with PROCEED: "
strAnswer=lCase(Trim(Wscript.StdIn.ReadLine))
If strAnswer <> "proceed" Then
	Wscript.Echo "aborted"
	Wscript.Quit
End If

'--open the ADS connection
Set m_objCommand.ActiveConnection = m_objConnection

'--loop through the recordset and create AD accounts
strPreviousRootName=""
nLoginNameSuffix=1
For nCounter=0 To uBound(m_strRS)

	'--get a record string
	strRecord=m_strRS(nCounter)
	
	'--split it into fields
	strRecordArray=Split(strRecord,g_strFieldDelim)
	m_strULName=strRecordArray(0)
	m_strUFName=strRecordArray(1)

	'--create sanitized version of the the first and last names (no special chars)
	m_strSanitizedULName=SanitizeName(m_strULName) 
	m_strSanitizedUFName=SanitizeName(m_strUFName)
	
	'--get up to the first 4 chars of the last name
	nLen=Len(m_strSanitizedULName)
	If nLen >= 4 Then
		strFirstPart=Left(m_strSanitizedULName,4)
	Else
		strFirstPart=Left(m_strSanitizedULName,nLen)
	End If

	'--get up to to the first two characters of the first name
	nLen=Len(m_strSanitizedUFName)
	If nLen >= 2 Then
		strSecondPart=Left(m_strSanitizedUFName,2)
	Else
		strFirstPart=Left(m_strSanitizedUFName,nLen)
	End If
		
	'--establish a provisional login name
	m_strRootName=lCase(Trim(strFirstPart & strSecondPart))
	
	'--see if the provisional login name is the same as the previous final login name and increment it if necessary
	If m_strRootName = strPreviousRootName Then	
		'--increment the suffix
		nLoginNameSuffix=nLoginNameSuffix+1
		m_strLoginName=m_strRootName & nLoginNameSuffix
	Else
		m_strLoginName=m_strRootName
		strPreviousRootName=m_strRootName
		nLoginNameSuffix=1
	End If
	m_strLoginName="site" & m_strSID & "_" & m_strLoginName
	
	'--Pre-process the AD account
	ADProcessRecord m_strULName, m_strUFName, m_strLoginName

Next
					

'--done
Wscript.Echo 
Wscript.Echo "--done!"
Wscript.Echo
Wscript.Quit

'//////////// Local Functions /////////////

Sub ADProcessRecord(strLastName,strFirstName,strLoginName)

	'--set the error indicator
	boolError=False
		
	'--assign the AD account name
	strAdAccountName=strLoginName
	
	'--start the console output line
	Wscript.StdOut.Write strAdAccountName & ": "
	
	'--verify site OU exists in AD
	If SiteExists(m_strSID) Then
		Wscript.StdOut.Write "site" & m_strSID & "_OU [Y]"
	Else
		Wscript.StdOut.Write "site" & m_strSID & "_OU [N]"
		boolError=True
	End If

	'--check for an existing AD group by this name
	m_objCommand.CommandText = _
   	 	"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='Group' AND Name = 'site" & m_strSID & "_group'"  
	Set objRecordSet = m_objCommand.Execute
	If objRecordSet.RecordCount = 0 Then
		Wscript.StdOut.Write ", site" & m_strSID & "_group [N]"
		boolError=True
	Else
		Wscript.StdOut.Write ", site" & m_strSID & "_group [Y]"
	End If

	'--see if the user account already exists
	If DoesAccountExist(strAdAccountName) Then
		Wscript.StdOut.Write ", " & strAdAccountName & " [Y]"
		boolError=True
	Else
		Wscript.StdOut.Write ", " & strAdAccountName & " [N]"
	End If

	'--create the account
	If Not boolError=True Then
		CreateUser strLastName,strFirstName,strAdAccountName,m_strSiteWinPwd,"User Account",m_strSID
	
		'--verify that it got created ok
		If DoesAccountExist(strAdAccountName) Then
			Wscript.StdOut.WriteLine ", [  OK  ]"
		Else
			Wscript.StdOut.WriteLine ", [ FAIL ]"
		End If
	Else
		Wscript.StdOut.WriteLine ", [ SKIP ]"
	End If

	'--sleep
	Wscript.Sleep 1000

End Sub

Sub CreateUser(strLastName,strFirstName,strLoginName,strPwd,strDesc,strSID)

	Wscript.StdOut.Write ", CreateUser(" & strLastName & "," & strFirstName & "," & strLoginName & "," & strPwd & "," & strDesc & ")"
	
	'--create the user account
	strObjectString="LDAP://ou=site" & strSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md"
	Set objOU = GetObject(strObjectString)
	Set objUser = objOU.Create("User", "cn=" & strLoginName)
	objUser.Put "sAMAccountName", strLoginName 
	objUser.Put "userPrincipalName", strLoginName & "@mycharts.md"
	objUser.Put "givenName", strFirstName 
	objUser.Put "sn", strLastName
	objUser.Put "displayName", strFirstName & strLastName 
	objUser.PutEx ADS_PROPERTY_UPDATE, "description", Array(strDesc)
	objUser.SetInfo

	'--set additional account params, force user to changed pw at login
	objUser.SetPassword strPwd
	'objUser.Put "PasswordExpired", CLng(1)
	objUser.AccountDisabled = FALSE
	'objUser.AccountExpirationDate = m_strExpirationDate
    objUser.Put "PwdLastSet", 0
	objUser.SetInfo
	
	'--add the user to the appropriate groups
	Set objGroup = GetObject("LDAP://cn=site" & strSID & "_group,ou=site" & strSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
	Set objGroup = GetObject("LDAP://cn=Remote Desktop Users,cn=Builtin,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
	Set objGroup = GetObject("LDAP://cn=Domain-Wide Terminal Services Users,cn=Users,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath

End Sub

Function SiteExists(m_strSID)
	m_objCommand.Properties("Page Size") = 1000
	m_objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	m_objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='organizationalUnit' AND Name = 'site" & m_strSID & "_OU'"  
	Set objRecordSet = m_objCommand.Execute
	If objRecordSet.RecordCount = 0 Then
		SiteExists=False
	Else
		SiteExists=True
	End If
End Function

Function DoesAccountExist(strAdAccountName)
	m_objCommand.Properties("Page Size") = 1000
	m_objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	m_objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='User' And Name='" & strAdAccountName & "' "  
	Set objRecordSet = m_objCommand.Execute
	If objRecordSet.RecordCount < 1 Then
		DoesAccountExist=False
	Else
		DoesAccountExist=True
	End If
End Function

Sub ShowUsage()
	Wscript.Echo
	Wscript.Echo "usage: add_partner_accounts --partner:<code> --password:<string> [--sitefile:<path>] "
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

Sub LogIt(strMsg)
	Logger strMsg,m_strLogDests
End Sub

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

Function SanitizeName(strString)
	Set objRegEx = CreateObject ("VBScript.RegExp")
	objRegEx.Global = True
	objRegEx.Pattern = "[^A-Za-z]"
	SanitizeName = Trim(objRegEx.Replace(strString, ""))
	Set objRegEx=Nothing
End Function

Sub RemoveRecord(nRecNoToRemove)

	'--create array for record selection 
	Dim m_strNewRS()
	Redim m_strNewRS(0)

	'--copy recordset to a new array except for the one we want to delete
	For nCounter=0 To uBound(m_strRS)
		If nCounter <> nRecNoToRemove Then
			'--add it to the new array, expand the new array as required
			If m_strNewRS(0)="" Then
				m_strNewRS(0)=m_strRS(nCounter)
			Else
				Redim Preserve m_strNewRS(uBound(m_strNewRS)+1)
				m_strNewRS(uBound(m_strNewRS))=m_strRS(nCounter)
			End If
		End If
	Next
	
	'--destroy the old array
	Redim m_strRS(0)
	
	'--copy recordset to a new array except for the one we want to delete
	For nCounter=0 To uBound(m_strNewRS)
		If nCounter > uBound(m_strRS) Then
			Redim Preserve m_strRS(uBound(m_strRS)+1)
		End If
		m_strRS(uBound(m_strRS))=m_strNewRS(nCounter)
	Next
	
End Sub

Sub DisplayRecordSet(nStartIndex)

	Wscript.Echo
	Wscript.Echo "Record selection"
	Wscript.Echo
 
	nCurrRow=0:nMaxRows=50
	
	'--display the records with index numbers
	'Wscript.Echo "nStartIndex=" & nStartIndex & ", uBound(m_strRS)=" & uBound(m_strRS)
	For nCounter=nStartIndex To uBound(m_strRS)
		
		'--get a record and split it into fields
		m_strRecArray=Split(m_strRS(nCounter),g_strFieldDelim)
		m_strULName=m_strRecArray(0)
		m_strUFName=m_strRecArray(1)
	
		'--output the record at the current row and column
		If nCounter < 10 Then 
			strIndex="0" & nCounter
		Else
			strIndex=nCounter
		End If
		strDisplayString="[" & strIndex & "] " & m_strULName & ", " & m_strUFName & " "
		
		'--display the string
		Wscript.Echo strDisplayString
		
		'--keep track of the last record displayed
		m_nDisplayLastRec=nCounter
		'Wscript.Echo "in DisplayRecordSet() m_nDisplayLastRec=" & m_nDisplayLastRec

		'--increment row
		nCurrRow=nCurrRow+1
		If nCurrRow > nMaxRows Then
			Wscript.Echo
			Exit Sub
		End If
	Next
 End Sub
 


