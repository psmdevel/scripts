'--purpose: adds new AD users for a site

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

'--create some objects
Set objDomain = GetObject("LDAP://dc=mycharts,dc=md")
Set oFS=CreateObject("Scripting.FileSystemObject")
Set objShell=CreateObject("Wscript.Shell")

'--init some vars
iUserCount=0
iSID=0
bInvArg=False
bDryRun=False

'--loop through the script arguments
Set objArgs=Wscript.Arguments
If objArgs.Count = 0 Then
	ShowUsage
	Wscript.Quit
End If

For iCount=0 To objArgs.Count - 1

	sArg=objArgs(iCount)
	iPos=Instr(sArg,":")

	If iPos > 0 Then 
		sLeft=Trim(Left(sArg,iPos-1))
		sRight=Trim(Right(sArg,Len(sArg)-iPos))
		Select Case sLeft
			Case "--site","-s"
				iSID=sRight
				If iSID <> vbNullString Then
					If Not IsNumeric(iSID) Then
						bInvArg=True
						Exit For
					Else
						If iSID < 1 Or iSID > 999 Then
							bInvArg=True
							Exit For
						End if
					End If
				Else
					bInvArg=True
					Exit For
				End If

			Case "--usercount"
				iUserCount=sRight
				If Not IsNumeric(iUserCount) Then
					bInvArg=True
					Exit For
				Else
					If iUserCount < 1 Or iUserCount > 50 Then
						bInvArg=True
						Exit For
					End If
				End If

			Case Else
				bInvArg=True
				Exit For

		End Select
	Else
		Select Case sArg
			Case "--dry-run" 
				bDryRun=True
			Case Else
				ShowUsage
				Quit
		End Select

	End If
Next

If bInvArg Then
	ShowUsage
	Wscript.Quit
End If

If iUserCount < 1 or iUserCount > 50 Then
	Wscript.Echo "must specify a user count in the range 1-50"
	Wscript.Quit
End If

'--got a SID?
If sReseller=vbNullString And iSID < 1 Then
	ShowUsage
	Wscript.Quit
End If

'--verify iSID length
If Len(iSID) <> 3 Then
	Wscript.Echo "site ID must be 3 digits"
	Wscript.Quit
End If

vSID=iSID

'--get the site windows password
strSQL="select win_pwd from sitetab where siteid='" & iSID & "';"
strPassword=PopRecord(QueryControlData(strSQL))
If strPassword="" Then
	Wscript.Echo "could not retireve site windows password"
	Wscript.Quit
End If

'--create ADS connection objects
Set objConnection = CreateObject("ADODB.Connection")
Set objCommand =   CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open "Active Directory Provider"
Set objCommand.ActiveConnection = objConnection

'--see it site exists in AD
If SiteExists(vSID) Then
	Set objUser=GetObject("LDAP://cn=site" & vSID &"_mapper,ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	sDesc = objUser.Get("description")
Else
	Wscript.Echo "site" & vSID & " does not exist in AD"
	Wscript.Quit
End If

'--verify site OU exists
If Not SiteExists(vSID) Then
	Wscript.Echo "--error: site OU does not exist, aborting."
	Wscript.Quit
End If

'--check for an existing group by this name
objCommand.CommandText = _
    "SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        "WHERE objectCategory='Group' AND Name = 'site" & vSID & "_group'"  
Set objRecordSet = objCommand.Execute
If objRecordSet.RecordCount = 0 Then
	Wscript.Echo "AD group 'site" & vSID & "_group' does not exist"
	Wscript.Quit
End If

'--confirm request for creation of new users
iCurrentUserCount=GetUserCount(vSID) 
Wscript.Echo
Wscript.Echo "         site: " & vSID 
Wscript.Echo "  description: " & sDesc
Wscript.Echo "current users: " & iCurrentUserCount	
Wscript.Echo "    new users: " & iUserCount
Wscript.Echo "     password: " & strPassword
Wscript.Echo "      dry-run: " & bDryRun
Wscript.Echo
Wscript.StdOut.Write "--respond with 'PROCEED': "
sAnswer=Wscript.StdIn.ReadLine
If Ucase(sAnswer) <> "PROCEED" Then
	Wscript.Echo "--aborted."
	Wscript.Quit
End If

Wscript.Echo "--creating [" & iUserCount & "] additional AD users for this site"
For i=iCurrentUserCount+1 to iCurrentUserCount+iUserCount
	If i < 99 Then
		If i < 10 Then
			vNum="00" & i
		Else
			vNum="0" & i
		End If
	Else
		vNum=i
	End If

	CreateUser "site" & vSID & "_" & vNum, strPassword, sDesc
Next

'--done
Wscript.Echo "--done!"
Wscript.Echo
Wscript.Quit

'//////////// Functions /////////////

Sub CreateUser(sUserName,strPassword,sDesc)

	If bDryRun=False Then
		Wscript.Echo "CreateUser(" & sUserName & "," & strPassword & "," & sDesc & ")"
	Else
		Wscript.Echo "CreateUser(" & sUserName & "," & strPassword & "," & sDesc & ") [dry-run]"
		Exit Sub
	End If

	Set objOU = GetObject("LDAP://ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")

	Set objUser = objOU.Create("User", "cn=" & sUserName)
	objUser.Put "sAMAccountName", sUserName 
	objUser.Put "userPrincipalName", sUserName & "@mycharts.md"
	objUser.Put "givenName", sUserName 
	objUser.Put "displayName", sUserName 
	objUser.PutEx ADS_PROPERTY_UPDATE, "description", Array(sDesc)
	objUser.SetInfo
	objUser.AccountDisabled=FALSE
	objUser.SetInfo

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
	objUser.SetInfo
	objUser.SetPassword strPassword

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

Function SiteExists(vSID)
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='organizationalUnit' AND Name = 'site" & vSID & "_OU'"  
	Set objRecordSet = objCommand.Execute
	If objRecordSet.RecordCount = 0 Then
		SiteExists=False
	Else
		SiteExists=True
	End If
End Function

Function GetUserCount(vSID)
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='User' And Name='site" & vSID & "_*' And Name <> 'site" & vSID & "_mapper' "  
	Set objRecordSet = objCommand.Execute
	intCount=0
	objRecordSet.MoveFirst
	Do While Not objRecordSet.EOF
		strTemp=objRecordSet.Fields(0)
		If Instr(strTemp,"site" & vSID & "_s") = 0 Then
			intCount=intCount+1
		End If
		objRecordSet.MoveNext
	Loop
	GetUserCount = intCount
End Function

Sub ShowUsage()
	Wscript.Echo
	Wscript.Echo "usage: addusers [--site|-s]:<ID> --usercount:<1-50>"
	Wscript.Echo
End Sub

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

Function QueryControlData(strSQL)
	strRS=vbNullString
	strRecord=vbNullString
	strCmd="""M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hdbclust11 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s -B --skip-column-names"
	Set objExec=objShell.Exec(strCmd)
	Do While Not objExec.StdOut.AtEndOfStream 
		strRecord=objExec.StdOut.ReadLine & vbCrLf
		strRS=strRS & strRecord
	Loop
	Set objExec=Nothing
	QueryControlData=strRS
End Function

Function PopRecord(strRS)
	intPos=Instr(strRS,vbCrLf)
	If intPos > 0 Then
		strRec=Left(strRS,intPos-1)
		strRS=Right(strRS,Len(strRS)-(intPos+1))
	Else
		strRec=strRS
		strRS=vbNullString
	End If
	PopRecord=Replace(strRec,"\\","\")
End Function
