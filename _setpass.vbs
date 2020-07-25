Option Explicit
'On Error Resume Next

Const ADS_SCOPE_SUBTREE = 2

Dim objRecordSet
Dim objCommand
Dim objConnection
Dim objUser
Dim strParentDN
Dim samName
Dim GivenName
Dim sn
Dim FullName
Dim GetString
Dim strOU, strSite, strPass
Dim i
Dim oArgs
Dim bInvalidArg, sArg, iPos, sLeft, sRight, iSID, sSID, sFromFile, sReseller, sResellers(), bDRY_RUN, sPassword
Dim bSupportAccountOnly, bMapperAccountOnly
Dim strRightPart

If Wscript.Arguments.Count = 0 Then
	ShowUsage
	Wscript.Quit
End If

'--loop through the arguments
bInvalidArg=False
bDRY_RUN=False
bSupportAccountOnly=False
bMapperAccountOnly=False
Set oArgs=Wscript.Arguments
For i=0 to oArgs.Count-1

	'--verify that it starts with "--"
	sArg=oArgs(i)
	If Not Left(sArg,2)="--" Then
		bInvalidArg=True
		Exit For
	End If


	'--verify arguments
	iPos=Instr(sArg,":")
	If iPos > 0 Then

		'--an argument was passed with a ":" so make sure both sides are there
		sLeft=Trim(Left(sArg,iPos-1))
		sRight=Trim(Right(sArg,Len(sArg)-iPos))
		If Len(sRight)=0 Then
			bInvalidArg=True
			Exit For
		End If

		Select Case sLeft

			Case "--site"
				iSID=sRight
				If Not isNumeric(iSID) Then
					bInvalidArg=True
					Exit For
				Else
					sSID=iSID
					If iSID > 0 And iSID < 1000 Then
						If Len(sSID)=1 Then
							sSID="00" & sSID
						Else
							If Len(sSID)=2 Then
								sSID="0" & sSID
							End If
						End if
					Else
						bInvalidArg=True
						Exit For
					End If	
				End If

			Case "--fromfile"
				sFromFile=sRight

			Case "--password"
				sPassword=sRight

			Case "--reseller"
				sReseller=sRight
				Select Case sReseller
					Case "psm","pt","gohs","gop","easemd","eqhip","ecw","curas","demo"
					Case Else
						bInvalidArg=True
						Exit For
				End Select

			Case Else
				bInvalidArg=True
				Exit For
		End Select

	Else

		Select Case sArg

			'--dry run?
			Case "--dry-run"
				bDRY_RUN=True

			'--support account only?
			Case "--support-account-only"
				bSupportAccountOnly=True

			'--mapper account only?
			Case "--mapper-account-only"
				bMapperAccountOnly=True

			Case Else
				bInvalidArg=True
				Exit For
		
		End Select

	End If
Next
If bInvalidArg Then
	ShowUsage
	Wscript.Quit
End If

If sSID <> "" And sReseller <> "" Then
	Wscript.Echo "cannot specify both a site ID and a reseller code"
	Wscript.Quit
End if

If sSID = "" And sReseller = "" Then
	Wscript.Echo "most specify a site ID or a reseller code"
	Wscript.Quit
End if

If (sReseller <> "" and sFromFile = "") Then
	Wscript.Echo "if specifying a reseller code, must also specify a fromfile"
	Wscript.Quit
End if

If sPassWord <> "" And sFromFile <> "" Then
	Wscript.Echo "cannot specify both a password and a fromfile"
	Wscript.Quit
End If

If sPassWord <> "" And sReseller <> "" Then
	Wscript.Echo "cannot specify both a password and a reseller"
	Wscript.Quit
End if

If sSID <> "" And sPassWord="" Then
	Wscript.Echo "if specifying a site ID, must also specify a password"
	Wscript.Quit
End If

If bMapperAccountOnly And bSupportAccountOnly Then
	Wscript.Echo "cannot specify both --support-account-only and --mapper-account-only"
	Wscript.Quit
End If

If sFromFile <> "" Then
Dim oFS
	Set oFS=CreateObject("Scripting.FileSystemObject")
	If Not oFS.FileExists(sFromFile) Then
		Wscript.Echo "the file '" & sFromFile & "' does not exist"
		Wscript.Quit
	End If
End if

If strPass <> "" And Not IsStrong(strPass) Then
	Wscript.Echo "password must be at least 8 upper, lower, and numeric characters"
	Wscript.Quit
End If
Wscript.Echo

If sReseller <> "" Then
	If bSupportAccountOnly Then
		Wscript.Echo "Are you SURE you want to reset the SUPPORT passwords for all sites of reseller '" & sReseller & "'?"
	Else
		If bMapperAccountOnly Then
			Wscript.Echo "Are you SURE you want to reset the MAPPER passwords for all sites of reseller '" & sReseller & "'?"
		Else
			Wscript.Echo "Are you SURE you want to reset the USER passwords for all sites of reseller '" & sReseller & "'?"
		End If
		
	End if
Else
	If bSupportAccountOnly Then
		Wscript.Echo "Are you SURE you want to reset the SUPPORT password for site" & sSID & "?"
	Else
		If bMapperAccountOnly Then
			Wscript.Echo "Are you SURE you want to reset the MAPPER password for site" & sSID & "?"
		Else
			Wscript.Echo "Are you SURE you want to reset the USER passwords for site" & sSID & "?"
		End If
	End If
	
End if
Wscript.StdOut.Write vbTab & "Type 'PROCEED' (anything else aborts):"
Dim sAnswer

sAnswer=Wscript.StdIn.ReadLine
If sAnswer <> "PROCEED" Then
	Wscript.Echo "aborted"
	Wscript.Quit
Else
	Wscript.Echo
End If

'--create ADS connection objects
set objConnection = CreateObject("ADODB.Connection")
set objCommand = CreateObject("ADODB.Command")
objConnection.Provider = "ADsDSOObject"
objConnection.Open("Active Directory Provider")
objCommand.ActiveConnection = objConnection

If sReseller <> "" Then
	Wscript.Echo
	Wscript.Echo "searching file '" & sFromFile & "' for customers of reseller '" & sReseller & "'..."
	Wscript.Echo
	Dim oInFile
	Err.Clear
	Set oInFile=oFS.OpenTextFile(sFromFile)
	If Err.Number <> 0 Then
		Wscript.Echo Err.Description
		Wscript.Quit
	End If
	Dim sLIne, sFields
	Do While Not oInFile.AtEndOfStream
		sLine=oInFile.ReadLine
		sFields=Split(sLine,":",9)
		If sFields(8)="@" & sReseller & ":" Then
			strSite=sFields(0)
			strPass=sFields(4)
			sSID=Right(strSite,Len(strSite)-4)
			If sSID > 0 Then
				DoChange strSite, strPass
			End If
		End if
	Loop
Else
	strPass=sPassWord
	strSite="site" & sSID
	DoChange strSite, strPass
End If

Function DoChange(strSite,strPass)
	strOU = "ou=" & strSite & "_OU,ou=ASP Users OU,dc=mycharts,dc=md"
	strParentDN = "LDAP://" & strOU

	objCommand.CommandText = "SELECT samAccountName,sn,GivenName,Name FROM '" & strParentDN _
            & "' WHERE objectClass='user' AND samAccountName='" & strSite & "*' ORDER BY samAccountName"
	objCommand.Properties("Page Size") = 1000
	objCommand.Properties("Searchscope") = ADS_SCOPE_SUBTREE

	set objRecordSet = objCommand.Execute
	If objRecordSet is Nothing Then
		Wscript.Echo "site '" & strSite & "' does not exist"
		Wscript.Quit
	End If

	objRecordSet.MoveFirst
	Do Until objRecordSet.EOF

		samName = objRecordSet.Fields("samAccountName").Value
        	sn = objRecordSet.Fields("sn").Value
        	FullName = objRecordSet.Fields("Name").Value
        	i = instr(FullName,",")
		If i>0 Then 
			FullName=Left(FullName,i-1) & "\" & Mid(FullName,i)
		End If
        	GivenName = objRecordSet.Fields("GivenName").Value
        	'GetString = "LDAP://cn=" & sn & "\, " & GivenName & "," & strOU
        	GetString = "LDAP://cn=" & FullName & "," & strOU
        	Set objUser = GetObject(GetString)
		'--pad it for display purposes
		Err.Clear
		Dim bProceed
		bProceed=True
		If Len(samName)=7 And Not bSupportAccountOnly Then bProceed=False
		If Len(samName)=14 And Not bMapperAccountOnly Then bProceed=False
		If Len(samName)=11 Then 
			If bSupportAccountOnly Or bMapperAccountOnly Then 
				bProceed=False
			End If
			strRightPart=Right(samName,3)
			If Not IsNumeric(strRightPart) Then
				bProceed=False
			End If
		End If
		If bProceed Then
			Dim sPadding
			sPadding=Space(14-Len(samName))
	        	Wscript.StdOut.Write samName & sPadding & ": change password -> " & strPass
			If bDRY_RUN Then
				Wscript.StdOut.Write " (dry-run) "
			Else
				objUser.SetPassword strPass
			End If
			If Err.Number <> 0 Then
				Wscript.StdOut.Write " [Error:" & Err.Description & "]" & vbCrLf
			Else
				Wscript.StdOut.Write " [OK]" & vbCrLf
			End If
		End If
        	objRecordSet.MoveNext
	Loop
End Function

Sub ShowUsage()
	Wscript.Echo "Usage:  setpass <options>"
	Wscript.Echo
	Wscript.Echo vbTab & "Options:"
	Wscript.Echo
	Wscript.Echo vbTab & "--site:<1-999>"
	Wscript.Echo vbTab & "--password:<string>"
	Wscript.Echo vbTab & "--fromfile:<file>"
	Wscript.Echo vbTab & "--reseller:<psm|pt|gohs|gop|easemd|eqhip|ecw|curas>"
	Wscript.Echo vbTab & "--mapper-account-only"
	Wscript.Echo vbTab & "--support-account-only"

	Wscript.Echo vbTab & "--dry-run"
End Sub

Function IsStrong(Password)
	Dim bUpper, bLower, bNumber, nLen, iPos, sChar
	bUpper=False
	bLower=False
	bNumber=False
	nLen=0
	IsStrong=False
	nLen=Len(Password)
	If nLen < 8 Then
		IsStrong=False
		Exit Function
	End If		
	For iPos=1 to Len(Password)
		sChar=Mid(Password,iPos,1)
		If Not bLower Then
			If Instr("abcdefghijklmnopqrstuvwxyz",sChar) > 0 Then bLower=True 	
		End If
		If Not bUpper Then
			If Instr("ABCDEFGHIJKLMNOPQRSTUVWXYZ",sChar) > 0 Then bUpper=True
		End If		
		If Not bNumber Then
			If Instr("0123456789",sChar) > 0 Then bNumber=True
		End If		
	Next
	IsStrong=(bUpper And bLower And bNumber)
End Function

