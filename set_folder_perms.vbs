'--edit the script to specify a root drive
strRootDrive="n:"

Set oFS=CreateObject("SCripting.FileSystemObject")
Set oFolder=oFS.GetFolder(strRootDrive & "\sites")
Set oShell=CreateObject("Wscript.Shell")
For Each oSubFolder In oFolder.SubFolders
	iSite=oSubFolder.Name
	If IsNumeric(iSite) Then

		'--set the file permissions
		Wscript.Echo "~: setting file permissions for site " & iSite & "..."
		sCmd="cacls " & strRootDrive & "\sites\" & iSite & " /t /e /g site" & iSite & "_group:c /r users"
		Err.Clear
		oShell.Run sCmd,0,True
		If Err.Description <> vbNullString Then
			Wscript.Echo "~: error: " & vbNullString
			Wscript.Echo "~: aborting."
		End If

		'--set the file permissions
		Wscript.Echo "~: deny access to the mapper account to program files for site " & iSite & "..."
		sCmd="cacls """ & strRootDrive & "\sites\" & iSite & "\Program Files"" /t /e /d site" & iSite & "_mapper"
		Err.Clear
		oShell.Run sCmd,0,True
		If Err.Description <> vbNullString Then
			Wscript.Echo "~: error: " & vbNullString
			Wscript.Echo "~: aborting."
		End If

	End If

Next


