'--purpose: shares all site folders with correct site-specific share names and permissions

'--edit the script to specify a root drive
strRootDrive="n:"

Const FILE_SHARE = 0
Const MAXIMUM_CONNECTIONS = 25
Set objShell=CreateObject("Wscript.Shell")
Set oFS=CreateObject("Scripting.FileSystemObject")
Set oSiteFolder=oFS.GetFolder(strRootDrive & "\sites")
strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
	& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set objNewShare = objWMIService.Get("Win32_Share")
For Each oFolder In oSiteFolder.SubFolders

	If IsNumeric(oFolder.Name) Then
		strSID=oFolder.Name	

		'--this way is cooler, but setting permissions on the share is harder
		'errReturn = objNewShare.Create _
    		'(strRootDrive & "\sites\" & oFolder.Name, "site" & oFolder.Name, FILE_SHARE, _
       		'	MAXIMUM_CONNECTIONS, "")

		'--this way is clunky but easier
		Wscript.Echo "sharing site" & strSID
		strCmd="net share site" & strSID & "=" & strRootDrive & "\sites\" & strSID & " /grant:everyone,full /users:25"
		objShell.Run strCmd,0,True
	End If	

Next