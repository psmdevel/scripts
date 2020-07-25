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

'--confirm request for c reation of new users
Wscript.Echo "Are you SURE you want to add 'siteXXX_mapper' accounts to all sites?"
Wscript.StdOut.Write "--respond with 'PROCEED': "
sAnswer=Wscript.StdIn.ReadLine
If Ucase(sAnswer) <> "PROCEED" Then
	Wscript.Echo "--aborted."
	Wscript.Quit
End If

Wscript.echo

'--create some objects
Set objDomain = GetObject("LDAP://dc=mycharts,dc=md")
Set oFS=CreateObject("Scripting.FileSystemObject")
Set oShell=CreateObject("Wscript.Shell")

'--make sure the sitetab file exists'
If Not oFS.FileExists("m:\scripts\sources\sitetab") Then
	Wscript.Echo "sitetab file does not exist"
	Wscript.Quit
End If

'--create ADS connection objects
Set objConnection = CreateObject("ADODB.Connection")
Set objCommand =   CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open "Active Directory Provider"
Set objCommand.ActiveConnection = objConnection

'--loop through the sitetab file
Set oInFile=oFS.OpenTextFile("m:\scripts\sources\sitetab")
sLine=oInFile.ReadLine
Do While Not oInFile.AtEndOfStream

	sLine=oInFile.ReadLine
	sFields=Split(sLine,":",9)

	'--get the sitename & make the vSID
	sSiteName=sFields(0)
	sWinPWD=sFields(5) & "_map"
	vSID=Right(sSiteName,Len(sSiteName) - 4)

	'--verify site actually exists in AD
	If Not SiteExists(vSID) Then
		Wscript.Echo "--site" & vSID & " does not exist in AD"
		Wscript.Quit
	End If

	'--get the description
	Set objUser=GetObject("LDAP://cn=site" & vSID &",ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	sDesc = objUser.Get("description")

	'--Create the user
	CreateUser sSiteName & "_mapper", sWinPwd, sDesc

Loop

'--done
Wscript.Echo "--done!"
Wscript.Echo
Wscript.Quit

'//////////// Functions /////////////

Sub CreateUser(sUserName,sWinPwd,sDesc)

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
	objUser.SetPassword sWinPwd

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

	'--set password never to expire
	intUAC = objUser.Get("userAccountControl")
	objUser.Put "userAccountControl", intUAC XOR ADS_UF_DONT_EXPIRE_PASSWD
    	objUser.SetInfo

	'--add the user to the appropriate group
	Set objGroup = GetObject("LDAP://cn=site" & vSID & "_group,ou=site" & vSID & "_OU,ou=ASP Users OU,dc=mycharts,dc=md")
	objGroup.Add objUser.ADSPath

End Sub

Function IsStrong(Password)
	bUpper=False:bLower=False:bNumbers=False
	For i=1 to Len(PassWord)
		sChar=Mid(Password,i,1)
		If Instr("ABCDEFGHIJKLMNOPQRSTUVWXYZ",sChar) Then
			bUpper=True
		End If
		If Instr("abcdefghijklmnopqrstuvwxyz",sChar) Then
			bLower=True
		End If
		If Instr("0123456789",sChar) Then
			bNumbers=True
		End If
	Next
	If i >=8 And bLower And bUpper And bNumbers Then
		IsStrong=True
	Else
		IsStrong=False
	End If
End Function

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
        	"WHERE objectCategory='User' And Name='site" & vSID & "_*'"  
	Set objRecordSet = objCommand.Execute
	GetUserCount = objRecordSet.RecordCount
End Function

Sub ShowUsage()
	Wscript.Echo "usage: addusers <site> <user_count> <password>"
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
