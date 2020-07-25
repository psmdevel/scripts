'On Error Resume Next


'--set the ADS constants
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

'--this line is now handled in LoadLibrary
'Const HKEY_LOCAL_MACHINE=&H80000002

'-display a blank line
Wscript.Echo

'--set defaults
m_boolEnableDebug=False
intUserCount=0
strBillable="yes"
m_strLogDests="console"

'--create some general objects
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set m_objShell=CreateObject("Wscript.Shell")

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
Else
	LogIt "debug: LoadLibrary succeeded"
End If

'--set the control data connection string
m_strControlDataConnStr=SetControlDataConnStr

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
			Case "--desc"
				strDesc=strRight				
			Case "--usercount"
				intUserCount=strRight
			Case "--dbcluster"
				strDbCluster=strRight
			Case "--rptserver"
				strRptServer=strRight
			Case "--billable"
				strBillable=strRight
			Case "--tz"
				strTimeZone=strRight
			Case "--reseller"
				strReseller=strRight			
			Case Else
				boolBadArg=True
				Exit For
		End Select
	Else
		boolBadArg=True
	End If
Next

'--verify all required args were passed
If strDesc="" or strTimeZone="" or strReseller="" Then
	LogIt "a required argument is missing"
	ShowUsage
	Wscript.Quit
End If

'--check timezone
Select Case strTimeZone
	Case "hst","pst","mst","cst","est"
	Case Else
		LogIt "invalid timezone"
		Wscript.Quit
End Select

'--check billable status
strBillable=Trim(lCase(strBillable))
If strBillable <> "yes" Then
	strBillable="no"
End If

'--ensure user count is numeric
If Not IsNumeric(intUserCount) Then
	boolBadArg=True
	LogIt "user count is not numeric"
Else
	If intUserCount < 0 Or intUserCount > 50 Then
		boolBadArg=True
		LogIt "user count is out of range"
	End If
End If

'--if an invalid argument was provided, show usage
If boolBadArg Then
	ShowUsage
	Wscript.Quit
End If

'--create ADS connection objects
LogIt "debug: creating AD objects"
Set objDomain = GetObject("LDAP://dc=mycharts,dc=md")
Set objConnection = CreateObject("ADODB.Connection")
Set objCommand =   CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open "Active Directory Provider"
Set objCommand.ActiveConnection = objConnection

'--get the server name we're logging into
Set m_objNet=CreateObject("Wscript.Network")
strThisComputer=lCase(m_objNet.ComputerName)

'--get the ts root folder record for this server from the database
strSQL="select site_root from ts_properties where name='" & strThisComputer & "';"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
If strRS(0)=vbNullString Then
	LogIt "no records returned when querying db for site root folder."
	Wscript.Quit
End If
strRootDir=strRS(0)

'--do a sanity check on the root folder
Select Case strRootDir
	Case "m:\","n:\"
	Case Else
		LogIt "invalid root directory '" & strRootDir & "'"
		Wscript.Quit
End Select

'--was site number specified?
vSID=intSID
If vSID <> vbNullString Then

	'--check for folder existence
	If m_objFS.FolderExists(strRootDir & "sites\" & vSID) Then
		LogIt "folder " & strRootDir & "sites\" & vSID & " exists."
		Wscript.Quit
	End If

	'--check for database entry
	strSQL="select siteid from sitetab where siteid='" & vSID & "';"
	strRS=DbQuery(strSQL,m_strControlDataConnStr)
	If strRS(0) <> vbNullString Then
		LogIt "site already exists in the control database"
		Wscript.Quit
	End If

Else
	'--find the next available site slot in active directory
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
    		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='organizationalUnit' AND Name = 'site*_OU'"  
	Set objRecordSet = objCommand.Execute
	iLastSID=0
	If objRecordSet.RecordCount > 0 Then
		objRecordSet.MoveFirst
		Do Until objRecordSet.EOF
    		sADString=objRecordSet.Fields("ADsPath").Value
    		If Instr(sADString,sSiteName & "_OU") Then
			vSID=Mid(sADString,15,3)
			If vSID > iLastSID Then
				iLastSID=vSID
			End If
    		End If
    		objRecordSet.MoveNext
		Loop
	End If
	vSID=iLastSID+1
	If vSID < 1000 Then
		If vSID < 10 Then
			vSid="00" & vSID
		Else
			If vSID < 100 Then
				vSID="0" & vSID
			End if
		End If
	Else
		LogIt "maximum site count (999) reached; aborting."
		Wscript.Quit
	End If
End If

'--if a db cluster was specified, verify that it is available; if not just get the next available cluster
boolClusterSpecified=False
If strDbCluster <> vbNullString Then
	boolClusterSpecified=True
	strSQL="select cluster_name from db_clusters where cluster_name='" & strDbCluster & "' and is_full <> 'yes';"
Else
	strSQL="select cluster_name from db_clusters where is_full <> 'yes' order by preference limit 1;"
End If
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strDbCluster=strRS(0)
If strDbCluster=vbNullString Then
	If boolClusterSpecified=True Then
		LogIt "the requested db cluster is not available"
	Else
		LogIt "could not find an available cluster"
	End if
	Wscript.Quit
End If

'--get the next available FTP server cluster
strSQL="select cluster_name from ftp_clusters where is_full='no' order by preference limit 1;"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strFtpCluster=strRS(0)
If strFtpCluster=vbNullString Then
	LogIt "could not identify an available ftp cluster"
	Wscript.Quit
End If

'--get the next available FTP folder path
strRS2=vbNullString 
strSQL="select folder_path from ftp_cluster_folders where cluster_name='" & strFtpCluster & "' and is_full='no' order by id limit 1;"
strRS2=DbQuery(strSQL,m_strControlDataConnStr)
strFtpClusterFolder=strRS2(0)
If strFtpClusterFolder=vbNullString Then
	LogIt "could not identify an available ftp store path"
	Wscript.Quit
End If

'--get the next available app cluster
strSQL="select id,a1,a2 from app_clusters where is_full <> 'yes' order by preference limit 1;"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strFields=Split(strRS(0),g_strFieldDelim)
strAppClustID=strFields(0)
strTomcatA=strFields(1)
strTomcatB=strFields(2)
If strTomcatA=vbNullString Or strTomcatB=vbNullString Then
	LogIt "could not assign tomcat servers"
	Wscript.Quit
End If

'--check the reseller id
strSQL="select reseller_id from resellers where reseller_id like '" & strReseller & "' limit 1;"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
If strRS(0) = vbNullString Then
	LogIt "invalid reseller id"
	Wscript.Quit
End If

'--get the terminal servers in the same cluster as the one we're on
LogIt "debug: getting terminal server cluster ID"
strSQL="select id,t1,t2,t3,t4 from ts_clusters where is_full <> 'yes' order by preference limit 1;"
strRS=DbQuery(strSQL,m_strControlDataConnStr)
strFields=Split(strRS(0),g_strFieldDelim)
strTsClustID=strFields(0)
LogIt "debug: strTsClustID=" & strTsClustID
Dim strTsArray()
Redim strTsArray(0)
If strTsClustID <> vbNullString Then
	For nTsNum=1 To 4
		strTsName=Trim(strFields(nTsNum))
		If strTsName <> vbNullString Then
			If nTsNum > 1 Then
				strTsList=strTsList & ", "
			End if
			strTsList=strTsList & strTsName
			If strTsName=strThisComputer Then
				strTsList=strTsList & " (this computer)"
			End If
			If strTsArray(0)=vbNullString Then
				strTsArray(0)=strTsName
			Else
				Redim Preserve strTsArray(uBound(strTsArray)+1)
				strTsArray(uBound(strTsArray))=strTsName
			End If
		End If
	Next
Else
	LogIt "could not get terminal server list"
	Wscript.Quit
End If

'--if no report server was specified, default to the dbcluster
If strRptServer=vbNullString Then
	strRptServer=strDbCluster
End If

'--convert the description to keywords for the database
strKeyWordsTmp=Trim(lCase(Replace(strDesc," ","_")))
strKeyWords=""
intLen=Len(strKeyWordsTmp)
For i=1 to intLen
	strChar=Mid(strKeyWordsTmp,i,1)
	If Instr("abcdefghijklmnopqrstuvwxyz1234567890_",strChar)=0 Then strChar=vbNullString
	strKeyWords=strKeyWords & strChar
Next

'--generate the passwords
strUserPwd=GenPassword
strSupPwd=GenPassword
strLowPwd=GenPassword
strHighPwd=GenPassword

Wscript.Echo
Wscript.Echo "  -- creating site: " & vSID 
Wscript.Echo "       description: " & strDesc
Wscript.Echo "       db_keywords: " & strKeywords
Wscript.Echo "        user count: " & intUserCount
Wscript.Echo "      user RDP pwd: " & strUserPwd
Wscript.Echo "   support RDP pwd: " & strSupPwd
Wscript.Echo "     low (dsn) pwd: " & strLowPwd
Wscript.Echo " high (dbuser) pwd: " & strHighPwd
Wscript.Echo "        db cluster: " & strDbCluster
Wscript.Echo "     report server: " & strRptServer
Wscript.Echo "    app cluster_id: " & strAppClustID
Wscript.Echo "       app servers: " & strTomcatA & ", " & strTomcatB
Wscript.Echo "       ftp cluster: " & strFtpCluster
Wscript.Echo "        ftp folder: " & strFtpClusterFolder
Wscript.Echo "     ts cluster_id: " & strTsClustID
Wscript.Echo "  terminal servers: " & strTSList
Wscript.Echo "    root directory: " & strRootDir
Wscript.Echo "          billable: " & strBillable
Wscript.Echo "          reseller: " & strReseller
Wscript.Echo
Wscript.StdOut.Write "   respond with 'PROCEED': "

strAnswer=Wscript.StdIn.ReadLine
If Ucase(strAnswer) <> "PROCEED" Then
	Wscript.Echo
	Wscript.Echo "   aborted."
	Wscript.Quit
End If

'--create new site folder from existing template
LogIt "copying " & strRootDir & "sites\_template to " & strRootDir & "sites\" & vSID
Err.Clear
m_objFS.CopyFolder strRootDir & "sites\_template", strRootDir & "sites\" & vSID, False
If Err.Description <> vbNullString Then
	LogIt "error: " & Err.Description
	Wscript.Quit
End If

'--create the site OU
Set objOU1 = GetObject("LDAP://ou=ASP Users OU,dc=mycharts,dc=md")
Err.Clear
Set objOU2 = objOU1.Create("organizationalUnit", "ou=site" & vSID & "_OU")
objOU2.SetInfo

'--verify site OU creation
If Not SiteExists(vSID) Then
	LogIt "site creation failed."
	Wscript.Quit
Else
	LogIt "site" & vSID & "_OU created"
End If

'--check for an existing group by this name
objCommand.CommandText = _
    "SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        "WHERE objectCategory='Group' AND Name = 'site" & vSID & "_group'"  
Set objRecordSet = objCommand.Execute
If objRecordSet.RecordCount = 0 Then

	'--create a security group
	LogIt "creating site" & vSID & "_group global security group"
	Set objOU = GetObject("LDAP://ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	Set objGroup = objOU.Create("Group", "cn=site" & vSID & "_group")
	objGroup.Put "sAMAccountName", "site" & vSID & "_group"
	objGroup.Put "groupType", ADS_GROUP_TYPE_GLOBAL_GROUP Or _
    	ADS_GROUP_TYPE_SECURITY_ENABLED
	objGroup.SetInfo

	'--add the saas_support group to the group
	LogIt "adding saas_support users to the group"
	Set objUser=GetObject("LDAP://cn=saas_support,cn=Users,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
Else
	'--old group exists, move it and the old user to the right place
	LogIt "found existing group in another container, moving it to site" & vSID & "_OU"
	Set objOU=GetObject("LDAP://ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")	
	objOU.MoveHere "LDAP://cn=site" & vSID & "_group,ou=ASP Users OU,dc=mycharts,dc=md", vbNullString
	objOU.MoveHere "LDAP://cn=site" & vSID & ",ou=ASP Users OU,dc=mycharts,dc=md", vbNullString
End If

'--create support user and add them to the group
LogIt "skipping creation of legacy support account (site" & vSID & ")"
'Set objUser = objOU.Create("User", "cn=site" & vSID)
'objUser.Put "sAMAccountName", "site" & vSID
'objUser.Put "userPrincipalName", "site" & vSID & "@mycharts.md"
'objUser.Put "givenName", "site" & vSID
'objUser.Put "displayName", "site" & vSID
'objUser.PutEx ADS_PROPERTY_UPDATE, "description", Array(strDesc)
'objUser.SetInfo
'objUser.AccountDisabled=FALSE
'objUser.SetInfo
'objUser.SetPassword strSupPwd

'--prevent user from being able to change password
'Set objSD = objUser.Get("ntSecurityDescriptor")
'Set objDACL = objSD.DiscretionaryAcl
'arrTrustees = array("nt authority\self", "EVERYONE")
'For Each strTrustee in arrTrustees
'	Set objACE = CreateObject("AccessControlEntry")
'	objACE.Trustee = strTrustee
'	objACE.AceFlags = 0
'	objACE.AceType = ADS_ACETYPE_ACCESS_DENIED_OBJECT
'	objACE.Flags = ADS_ACEFLAG_OBJECT_TYPE_PRESENT
'	objACE.ObjectType = CHANGE_PASSWORD_GUID
'	objACE.AccessMask = ADS_RIGHT_DS_CONTROL_ACCESS
'	objDACL.AddAce objACE
'Next
'objSD.DiscretionaryAcl = objDACL
'objUser.Put "nTSecurityDescriptor", objSD
'objUser. SetInfo

'--set password never to expire
'intUAC = objUser.Get("userAccountControl")
'objUser.Put "userAccountControl", intUAC XOR ADS_UF_DONT_EXPIRE_PASSWD
'objUser.SetInfo

'--add the user to the appropriate groups
'Set objGroup = GetObject("LDAP://cn=site" & vSID & "_group,ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
'objGroup.Add objUser.ADSPath
'Set objGroup = GetObject("LDAP://cn=Remote Desktop Users,cn=Builtin,dc=mycharts,dc=md")
'objGroup.Add objUser.ADSPath
'Set objGroup = GetObject("LDAP://cn=Domain-Wide Terminal Services Users,cn=Users,dc=mycharts,dc=md")
'objGroup.Add objUser.ADSPath

'--create mapper user and add them to the group
LogIt "creating mapper user (site" & vSID & "_mapper) for this site"
Set objUser = objOU.Create("User", "cn=site" & vSID & "_mapper")
objUser.Put "sAMAccountName", "site" & vSID & "_mapper"
objUser.Put "userPrincipalName", "site" & vSID & "_mapper@mycharts.md"
objUser.Put "givenName", "site" & vSID & "_mapper"
objUser.Put "displayName", "site" & vSID & "_mapper"
objUser.PutEx ADS_PROPERTY_UPDATE, "description", Array(strDesc)
objUser.SetInfo
objUser.AccountDisabled=FALSE
objUser.SetInfo
objUser.SetPassword strLowPwd

'--prevent user from being able to change password
Set objSD = objUser.Get("ntSecurityDescriptor")
Set objDACL = objSD.DiscretionaryAcl
arrTrustees = array("nt authority\self", "EVERYONE")
For Each strTrustee in arrTrustees
	Set objACE = CreateObject("AccessControlEntry")
	objACE.Trustee = strTrustee
	objACE.AceFlags = 0
	objACE.AceType = ADS_ACETYPE_ACCESS_DENIED_OBJECT
	objACE.Flags = ADS_ACEFLAG_OBJECT_TYPE_PRESENT
	objACE.ObjectType = CHANGE_PASSWORD_GUID
	objACE.AccessMask = ADS_RIGHT_DS_CONTROL_ACCESS
	objDACL.AddAce objACE
Next
objSD.DiscretionaryAcl = objDACL
objUser.Put "nTSecurityDescriptor", objSD
objUser. SetInfo

'--set password never to expire
intUAC = objUser.Get("userAccountControl")
objUser.Put "userAccountControl", intUAC XOR ADS_UF_DONT_EXPIRE_PASSWD
objUser.SetInfo

'--add the user to the appropriate groups
Set objGroup = GetObject("LDAP://cn=site" & vSID & "_group,ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
objGroup.Add objUser.ADSPath

'--create standard users if appropriate
LogIt "creating [" & intUserCount & "] standard AD users for this site"
For i=1 To intUserCount
	If intUserCount < 99 Then
		If i < 10 Then
			vNum="00" & i
		Else
			vNum="0" & i
		End If
	End If
	CreateUser vNum
Next

'--set the file permissions
LogIt "setting filesystem permissions"
sCmd="cacls " & strRootDir & "sites\" & vSID & " /t /e /g site" & vSID & "_group:c /r users"
Err.Clear
m_objShell.Run sCmd,0,True
If Err.Description <> vbNullString Then
	LogIt "error: " & vbNullString
End If

'--edit the configuration.xml file
LogIt "customizing configuration.xml"
strCfgNew=strRootDir & "sites\" & vSID & "\program files\eclinicalworks\configuration.xml.new"
strCfgFile=strRootDir & "sites\" & vSID & "\program files\eclinicalworks\configuration.xml"
Set objCfgFile=m_objFS.OpenTextFile(strCfgFile,1)
Set oCfgNew=m_objFS.OpenTextFile(strCfgNew,2,True)
Do While Not objCfgFile.AtEndOfStream
	sLine=objCfgFile.ReadLine

	'--edit the server port
	If Instr(sLine,"</server>") Then
		sLine=vbTab & "<server>extrovert:3" & vSID & "</server>"
	End If

	'--edit the dsn
	If Instr(sLine, "</dsn>") Then
		sLine=vbTab & "<dsn>site" & vSID & "</dsn>"
	End If

	'--edit the db
	If Instr(sLine, "</db>") Then
		sLine=vbTab & "<db>mobiledoc_" & vSID & "</db>"
	End If
	
	'--edit the user
	If Instr(sLine, "</user>") Then
		sLine=vbTab & "<user>site" & vSID & "</user>"
	End If
	
	'--edit the password
	If Instr(sLine, "</pwd>") Then
		sLine=vbTab & "<pwd>" & strLowPwd & "</pwd>"
	End If

	'--edit the practice
	If Instr(sLine, "</Practice>") Then
		sLine=vbTab & "<Practice>site" & vSID & "</Practice>"
	End If
	
	'--edit the ftp user
	If Instr(sLine, "</ftpserver>") Then
		sLine=vbTab & "<ftpserver>" & strFtpCluster & "</ftpserver>"
	End If

	'--edit the ftp user
	If Instr(sLine, "</ftpuser>") Then
		sLine=vbTab & "<ftpuser>site" & vSID & "</ftpuser>"
	End If

	'--edit the ftp password
	If Instr(sLine, "</ftppwd>") Then
		sLine=vbTab & "<ftppwd>" & strLowPwd & "</ftppwd>"
	End If

	oCfgNew.WriteLine sLine
Loop
Set objCfgFile=Nothing
Set oCfgNew=Nothing
If m_objFS.FileExists(strCfgNew) Then
	m_objFS.DeleteFile strCfgFile
	m_objFS.MoveFile strCfgNew, strCfgFile
Else
	LogIt "failed to create new configuration file; aborting."
	Wscript.Quit
End If 

'--write dsn_names.txt file
LogIt "creating dsn_names.txt"
Err.Clear
Set oFile=m_objFS.OpenTextFile(strRootDir & "sites\" & vSID & "\ecw\dsn_names.txt",2,True)
oFile.WriteLine "site" & vSID
If Err.Description <> vbNullString Then
	LogIt "error: could not create dsn_names.txt (" & Err.Description & "); aborting"
	Wscript.Quit
End If
Set oFile=Nothing

'--edit mobiledoccfg.properties
LogIt "customizing mobiledoccfg.properties"
strCfgFile=strRootDir & "sites\" & vSID & "\eclinicalworks\tomcat\webapps\mobiledoc\conf\mobiledoccfg.properties"
strCfgNew=strRootDir & "sites\" & vSID & "\eclinicalworks\tomcat\webapps\mobiledoc\conf\mobiledoccfg.properties.new"
Set objCfgFile=m_objFS.OpenTextFile(strCfgFile,1)
Set oCfgNew=m_objFS.OpenTextFile(strCfgNew,2,True)
Do While Not objCfgFile.AtEndOfStream
	sLine=objCfgFile.ReadLine

	If Instr(sLine,"mobiledoc.DBName") Then
		sLine="mobiledoc.DBName=mobiledoc_" & vSID
	End If

	If Instr(sLine,"mobiledoc.DBPassword") Then
		sLine="mobiledoc.DBPassword=" & strLowPwd
	End If

	If Instr(sLine,"mobiledoc.DBUser") Then
		sLine="mobiledoc.DBUser=site" & vSID
	End If

	If Instr(sLine,"mobiledoc.HospitalName") Then
		sLine="mobiledoc.HospitalName=" & strDesc
	End If
	
	oCfgNew.WriteLine sLine
Loop
Set objCfgFile=Nothing
Set oCfgNew=Nothing
If m_objFS.FileExists(strCfgNew) Then
	m_objFS.DeleteFile strCfgFile
	m_objFS.MoveFile strCfgNew,strCfgFile
Else
	LogIt "error: failed to create mobiledoccfg.properties; aborting."
	Wscript.Quit
End If 

'--create dsn
Err.Clear
LogIt "creating 'site" & vSID & "' DSN on " & strThisComputer
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources\site" & vSID, "MySQL ODBC 5.1 Driver", "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Database", "mobiledoc_" & vSID, "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Description", "", "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Driver", "M:\Program Files (x86)\MySQL\Connector ODBC 5.1\myodbc5.dll", "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Option", "0", "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Password", strLowPwd, "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Port", "5" & vSID, "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Server", strRptServer, "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\Stmt", "", "REG_SZ"
m_objShell.RegWrite "HKLM\Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID & "\User", "site" & vSID, "REG_SZ"
If Err.Description <> vbNullString Then
	LogIt "warning: could not create ODBC registry entries."
End If

'--create the remote DSNs
For nTsNum=0 To uBound(strTsArray)
	strRemoteTsName=strTsArray(nTsNum)
	If strRemoteTsName <> strThisComputer And strRemoteTsName <> vnNullString Then

		LogIt "creating 'site" & vSID & "' DSN on " & strRemoteTsName
		Set objReg=GetObject("WinMgmts:{impersonationLevel=impersonate}!//" & strRemoteTsName & "/root/default:stdRegProv")
	
		'--create the ODBC data source
		strKeyPath = "Software\Wow6432Node\ODBC\ODBC.INI\ODBC Data Sources"
		strValueName = "site" & vSID
		strValue = "MySQL ODBC 5.1 Driver"
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		'--create the ODBC entry and set the path for the remaining values
		strKeyPath = "Software\Wow6432Node\ODBC\ODBC.INI\site" & vSID
		objReg.CreateKey HKEY_LOCAL_MACHINE,strKeyPath

		'--populate the settings for this key
		strValueName = "Database"
		strValue = "mobiledoc_" & vSID
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Driver"
		strValue = "M:\Program Files (x86)\MySQL\Connector ODBC 5.1\myodbc5.dll"
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Option"
		strValue = "0"
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Password"
		strValue = strLowPwd
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Port"
		strValue = "5" & vSID
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Server"
		strValue = strRptServer
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "Stmt"
		strValue = ""
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

		strValueName = "User"
		strValue = "site" & vSID
		objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
		Set oreg=Nothing
	End If
Next

'--share the site folder
LogIt "creating the network share"
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set objNewShare = objWMIService.Get("Win32_Share")
errReturn = objNewShare.Create _
    (strRootDir & "sites\" & vSID, "site" & vSID, FILE_SHARE, _
        MAXIMUM_CONNECTIONS, "")

'--copy the cwuidefs.xml file to the other terminal servers
strRemoteRoot=Replace(strRootDir,":","$")
strLocalFile=strRootDir & "sites\" & vSID & "\Program Files\eClinicalWorks\CwUidefs.xml"
For nTsNum=0 To uBound(strTsArray)
	strTsName=strTsArray(nTsNum)
	If strTsName <> vbNullString Then
		If strTsName <> strThisComputer Then
			LogIt "copying CwUiDefs.xml to server " & strTsName & "; max 30 second wait..."
			Err.Clear
			strRemoteDir="\\" & strTsName & "\" & strRemoteRoot & "sites\" & vSID & "\Program Files\eClinicalWorks\"
			boolCopied=False
			intSeconds=30
			Do While intSeconds > 0
				If m_objFS.FolderExists(strRemoteDir) Then
					m_objFS.CopyFile strLocalFile, strRemoteDir
  					If Err.Number <> 0 Then
						LogIt "error copying file [" & Err.Description & "]"
					Else
						boolCopied=True
						Exit Do
					End If
				End If
				Wscript.Sleep 1000
				intSeconds=intSeconds-1
			Loop
			If boolCopied=False Then
				LogIt "file not copied"
			End If
		End If
	End If
Next

'--update the sitetab table
strSQL="INSERT into sitetab(keywords," & _
"siteid," & _
"status," & _
"win_pwd," & _
"dsn_pwd," & _
"dbuser_pwd," & _
"support_pwd," & _
"time_zone," & _
"reseller_id," & _
"db_cluster," & _
"ftp_cluster," & _
"ftp_cluster_folder," & _
"billable," & _
"install_status," & _
"ts_cluster_id," & _
"app_cluster_id) " & _
"VALUES('" & strKeyWords & "','" & vSID & "','active'," & _
"'" & strUserPwd & "'," & _
"'" & strLowPwd & "'," & _
"'" & strHighPwd & "'," & _
"'" & strSupPwd & "'," & _
"'" & strTimeZone & "'," & _
"'" & strReseller & "'," & _
"'" & strDbCluster & "'," & _
"'" & strFtpCluster & "'," & _
"'" & strFtpClusterFolder & "'," & _
"'" & strBillable & "'," & _
"'ts_complete'," & _
"'" & strTsClustID & "'," & _
"'" & strAppClustID & "');" 
Wscript.Echo
DbQuery strSQL,m_strControlDataConnStr

'--done
LogIt "done!"
Wscript.Echo
Wscript.Quit

'#################################################
'#                                               #
'#               Functions                       #
'#                                               #
'#################################################

Sub LogIt(strMsg)
	Logger strMsg,m_strLogDests
End Sub

Sub CreateUser(vNum)
	Set objUser = objOU.Create("User", "cn=site" & vSID & "_" & vNum)
	objUser.Put "sAMAccountName", "site" & vSID & "_" & vNum
	objUser.Put "userPrincipalName", "site" & vSID & "_" & vNum & "@mycharts.md"
	objUser.Put "givenName", "site" & vSID & "_" & vNum
	objUser.Put "displayName", "site" & vSID & "_" & vNum
	objUser.PutEx ADS_PROPERTY_UPDATE, "description", Array(strDesc)
	objUser.SetInfo
	objUser.AccountDisabled=FALSE
	objUser.SetInfo
	objUser.SetPassword strUserPwd

	'--prevent user from being able to change password
	Set objSD = objUser.Get("ntSecurityDescriptor")
	Set objDACL = objSD.DiscretionaryAcl
	arrTrustees = array("nt authority\self", "EVERYONE")
	For Each strTrustee in arrTrustees
    		Set objACE = CreateObject("AccessControlEntry")
    		objACE.Trustee = strTrustee
    		objACE.AceFlags = 0
    		objACE.AceType = ADS_ACETYPE_ACCESS_DENIED_OBJECT
    		objACE.Flags = ADS_ACEFLAG_OBJECT_TYPE_PRESENT
    		objACE.ObjectType = CHANGE_PASSWORD_GUID
    		objACE.AccessMask = ADS_RIGHT_DS_CONTROL_ACCESS
    		objDACL.AddAce objACE
	Next
	objSD.DiscretionaryAcl = objDACL
	objUser.Put "nTSecurityDescriptor", objSD
	objUser. SetInfo

	'--set password never to expire
	intUAC = objUser.Get("userAccountControl")
	objUser.Put "userAccountControl", intUAC XOR ADS_UF_DONT_EXPIRE_PASSWD
    	objUser.SetInfo

	'--add the user to the appropriate groups
	Set objGroup = GetObject("LDAP://cn=site" & vSID & "_group,ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
	Set objGroup = GetObject("LDAP://cn=Remote Desktop Users,cn=Builtin,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
	Set objGroup = GetObject("LDAP://cn=Domain-Wide Terminal Services Users,cn=Users,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath
End Sub

Function GenPassword()
	boolUpper=False
	boolLower=False
	boolNumber=False
	Dim strCharset(2)
	strCharset(0)="ABCDEFGHIJKLMNPQRSTUVWXYZ"
	strCharset(1)="abcdefghjkmnopqrstuvwxyz"
	strCharset(2)="123456789"
	strPass=""

	'--loop 8 times to create an 8-character password
	intCharNum=1
	Do While True

		'--select a character set
		Randomize
		intCharSetNum=Int(3 * Rnd)
		Select Case intCharSetNum
			Case 0
				boolUpper=True
			Case 1
				boolLower=True
			Case 2
				boolNumber=True
		End Select

		'--get the length of the select charset
		intLen=Len(strCharset(intCharSetNum))

		'--pick a character from the charset
		intCharPick=Int(intLen * Rnd + 1)
		strChar=Mid(strCharset(intCharSetNum),intCharPick,1)

		'--failsafe: ensures at least 1 upper, lower, and number character
		If intCharNum=8 Then
			If boolUpper And boolLower And boolNumber Then
				strPass=strPass & strChar
				Exit Do
			End If
		Else
			strPass=strPass & strChar
			intCharNum=intCharNum+1
		End If
	Loop
	GenPassword=strPass
End Function

Function SiteExists(SID)
	SiteExists=True
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


