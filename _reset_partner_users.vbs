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

'--create the objects
Set objDomain = GetObject("LDAP://dc=mycharts,dc=md")
Set objFS=CreateObject("Scripting.FileSystemObject")
Set objShell=CreateObject("Wscript.Shell")

'--init the vars
nSID=0
bInvArg=False
bDryRun=False
strSiteFile=vbNullString
strPartnerPwd=vbNullString
strPartner=vbNullString

'--loop through the script arguments
Set objArgs=Wscript.Arguments
If objArgs.Count = 0 Then
	ShowUsage
	Wscript.Quit
End If

For iCount=0 To objArgs.Count - 1

	strArg=objArgs(iCount)
	iPos=Instr(strArg,":")

	If iPos > 0 Then 
		strLeft=Trim(Left(strArg,iPos-1))
		strRight=Trim(Right(strArg,Len(strArg)-iPos))
		Select Case strLeft

			Case "--partner"
				strPartner=strRight

			Case "--password"
				strPartnerPwd=strRight

			Case "--sitefile"
				strSiteFile=strRight

			Case Else
				bInvArg=True
				Exit For

		End Select
	Else
		Select Case strArg
			Case "--dry-run"
				bDryRun=True
			Case Else
				bInvArg=True
				Exit For
		End Select
	End If
Next

If bInvArg Then
	ShowUsage
	Wscript.Quit
End If

'--see if a valid partner id was provided
strSQL="select reseller_id from resellers where reseller_id='" & strPartner & "';"
strRS=QueryControlData(strSQL)
If strRS=vbNullString Then
	LogIt "invalid partner id specified"
	Wscript.Quit
End If

'--see if a password is strong enough
If Not IsPwdStrong(strPartnerPwd) Then
	LogIt "password test fails"
	Wscript.Quit
End If 

'--get the reseller slot
strSQL="select reseller_slot from resellers where reseller_id='" & strPartner & "';"
strResellerSlot=PopRecord(QueryControlData(strSQL))
If strResellerSlot=vbNullString Then
	LogIt "no reseller slot found"
	Wscript.Quit
End If

'--if a site file was specified, make sure it exists
If strSiteFile <> vbNullString Then
	If Not objFS.FileExists(strSiteFile) Then
		LogIt "site file '" & strSiteFile & "' was not found."
		Wscript.Quit 
	End If
End If

'--create ADS connection objects
Set objConnection = CreateObject("ADODB.Connection")
Set objCommand =   CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open "Active Directory Provider"
Set objCommand.ActiveConnection = objConnection

'--populate the site list array
Dim strSIDs()
Redim strSIDs(0)
If strSiteFile=vbNullString Then
	'--get the list from sitetab
	If strPartner="ecw" Or strPartner="psm" Then
		strSQL="select siteid from sitetab where siteid > 0 and status='active' order by siteid;"
	Else
		strSQL="select siteid from sitetab where siteid > 0 and reseller_id='" & strPartner & "' and status='active' order by siteid;"
	End If
	strRS=QueryControlData(strSQL)
	Do While strRS <> vbNullString
		strSID=PopRecord(strRS)
		If strSIDs(0) <> vbNullString Then
			Redim Preserve strSIDs(uBound(strSIDs)+1)
		End If
		strSIDs(uBound(strSIDs))=strSID
	Loop
Else
	'--get the list from a file
	Set objSiteFile=objFS.OpenTextFile(strSiteFile,1)
	Do While Not objSiteFile.AtEndOfStream
		strSID=objSiteFile.ReadLine
		If strSIDs(0) <> vbNullString Then
			Redim Preserve strSIDs(uBound(strSIDs)+1)
		End If
		strSIDs(uBound(strSIDs))=strSID
	Loop
	
End If

'--display site list
nSiteCount=uBound(strSIDs)+1
Wscript.Echo "--- " & nSiteCount & " sites ---"
For nIndex=0 To uBound(strSIDs)
	If nIndex > 0 Then
		Wscript.StdOut.Write ","
	End If
	Wscript.StdOut.Write strSIDs(nIndex)
Next
Wscript.Echo
Wscript.Echo

'--confirm request for creation of new users
Wscript.Echo "partner: " & strPartner
Wscript.Echo "account: siteXXX_s" & strResellerSlot 
Wscript.Echo " passwd: " & strPartnerPwd
Wscript.Echo "  sites: " & nSiteCount
Wscript.Echo "dry-run: " & bDryRun
Wscript.Echo
Wscript.StdOut.Write "--respond with 'PROCEED': "
sAnswer=Wscript.StdIn.ReadLine
If Ucase(sAnswer) <> "PROCEED" Then
	Wscript.Echo "--aborted."
	Wscript.Quit
End If
Wscript.Echo

'--loop through the site list
For nIndex=0 To uBound(strSIDs)
	
	'--set the error indicator
	boolError=False

	'--get the SID
	strSID=strSIDs(nIndex)
	Wscript.StdOut.Write "site" & strSID & ": "

	'--verify site OU exists in AD
	If SiteExists(strSID) Then
		Wscript.StdOut.Write "site" & strSID & "_OU [ou]"
	Else
		Wscript.StdOut.Write "site" & strSID & "_OU [!ou]"
		boolError=True
	End If

	'--check for an existing group by this name
	objCommand.CommandText = _
   	 	"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        		"WHERE objectCategory='Group' AND Name = 'site" & strSID & "_group'"  
	Set objRecordSet = objCommand.Execute
	If objRecordSet.RecordCount = 0 Then
		Wscript.StdOut.Write ", site" & strSID & "_group [!ad_group]"
		boolError=True
	Else
		Wscript.StdOut.Write ", site" & strSID & "_group [ad_group]"
	End If

	'--check for an existing partner user account for this site
	strPartnerAccount="site" & strSID & "_s" & strResellerSlot 
	If DoesAccountExist(strPartnerAccount) Then
		Wscript.StdOut.Write ", " & strPartnerAccount & " [partner_account]"
	Else
		Wscript.StdOut.Write ", " & strPartnerAccount & " [!partner_account]"
		boolError=True
	End If

	'--set the partner password for site
	If Not boolError Then
		DoChange strSID	
		Wscript.Echo 
		'--sleep
		Wscript.Sleep 1000
	End If

Next
Wscript.Echo 

'--done
Wscript.Echo "--done!"
Wscript.Echo
Wscript.Quit

'//////////// Functions /////////////

Sub DoChange(strSID)

	'--set site and partner account name
	strSite="site" & strSID
	strPartnerAccount="site" & strSID & "_s" & strResellerSlot

	'--set the ou ParentDN string
	strOU = "ou=" & strSite & "_OU,ou=ASP Users OU,dc=mycharts,dc=md"
	strParentDN = "LDAP://" & strOU

	'Wscript.Echo "debug: strParentDN=" & strParentDN

	'--get the partner account from AD
	strCmdText="SELECT samAccountName,sn,GivenName,Name FROM '" & strParentDN _
            		& "' WHERE objectClass='user' AND samAccountName='" & strPartnerAccount & "'"
	'Wscript.Echo "debug: strCmdText=" & strCmdText
	objCommand.CommandText = strCmdText
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE
	set objRecordSet = objCommand.Execute
	If objRecordSet is Nothing Then
		Wscript.Echo "site '" & strSite & "' partner account does not exist"
		Wscript.Quit
	End If

	'--get the full name field
        FullName = objRecordSet.Fields("Name").Value

	'--if the field has a comma in it, escape it
       	i = instr(FullName,",")
	If i>0 Then 
		FullName=Left(FullName,i-1) & "\" & Mid(FullName,i)
	End If

	'--assemble the get string
       	GetString = "LDAP://cn=" & FullName & "," & strOU

	'--set the user object
       	Set objUser = GetObject(GetString)

	'--change the password
        Wscript.StdOut.Write FullName & ": change password -> " & strPartnerPwd
	If bDryRun Then
		Wscript.StdOut.Write " (dry-run) "
	Else
		objUser.SetPassword strPartnerPwd
	End If

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

Function SiteExists(strSID)
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='organizationalUnit' AND Name = 'site" & strSID & "_OU'"  
	Set objRecordSet = objCommand.Execute
	If objRecordSet.RecordCount = 0 Then
		SiteExists=False
	Else
		SiteExists=True
	End If
End Function


Function DoesAccountExist(strAccountName)
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='User' And Name='" & strAccountName & "' "  
	Set objRecordSet = objCommand.Execute
	If objRecordSet.RecordCount < 1 Then
		DoesAccountExist=False
	Else
		DoesAccountExist=True
	End If
End Function


Function GetUserCount(strSID)
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE 
	objCommand.CommandText = _
		"SELECT ADsPath FROM 'LDAP://dc=mycharts,dc=md' " & _
        	"WHERE objectCategory='User' And Name='site" & strSID & "_*' And Name <> 'site" & strSID & "_mapper' "  
	Set objRecordSet = objCommand.Execute
	GetUserCount = objRecordSet.RecordCount
End Function

Sub ShowUsage()
	Wscript.Echo
	Wscript.Echo "usage: reset_partner_accounts --partner:<code> --password:<string> [--sitefile:<path>] [--dry-run]"
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

Sub LogIt(strMsg)
	If Instr(strMsg,"debug:") > 0 Then
		If boolDebug=False Then
			Exit Sub
		End If
	End If
	Wscript.Echo "~: " & strMsg
End Sub

Function IsPwdStrong(strPwd)

	nScore=0

	'--verify it is al least 8 chars
	If Len(strPwd) >=9 Then nScore=nScore+1

	'--verify at least one upper case char
	boolFound=False
	For nChar=1 To Len(strPwd)
		strChar=Mid(strPwd,nChar,1)
		If Instr("ABCDEFGHIJKLMNOPQRSTUVWXYZ",strChar) > 0 Then
			boolFound=True
			Exit For
		End If
	Next
	If boolFound Then 
		nScore=nScore+1
	End If

	'--verify at least one lower case char
	boolFound=False
	For nChar=1 To Len(strPwd)
		strChar=Mid(strPwd,nChar,1)
		If Instr("abcdefghijklmnopqrstuvwxyz",strChar) > 0 Then
			boolFound=True
			Exit For
		End If
	Next
	If boolFound Then 
		nScore=nScore+1
	End If

	'--verify at least one number
	boolFound=False
	For nChar=1 To Len(strPwd)
		strChar=Mid(strPwd,nChar,1)
		If Instr("0123456789",strChar) > 0 Then
			boolFound=True
			Exit For
		End If
	Next
	If boolFound Then 
		nScore=nScore+1
	End If


	'--score it
	If nScore=3 Then
		IsPwdStrong=True
	Else
		IsPwdStrong=False
	End If


End Function

