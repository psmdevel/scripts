'--script purpose: set up environment and launch eclinicalworks
'  last edited: 04/02/2019
'  author: eric robinson
'
'--On Error Resume Next

'--set general constants
Const SCRIPT_VERSION=4.0
Const HKEY_CURRENT_USER = &H80000001

'--constants for file access modes
Const FOR_READ=1
Const FOR_WRITE=2
Const FOR_APPEND=8

'--enable or disable debug logging
m_boolEnableDebug=true

'--assume for the moment that we are not going to automatically log off the user
m_boolLogoff=False

'--create the basic objects
Set m_objFS = CreateObject("Scripting.FileSystemObject")
Set m_objShell=Wscript.CreateObject("Wscript.Shell")
Set m_objWshNetwork = WScript.CreateObject("WScript.Network")

'--get the lower case version of this terminal server's name
m_strServerName=Trim(lCase(m_objWshNetwork.ComputerName))

'--set the m_strComputer var to local
m_strComputer = "."

'--get the lower case version of the client workstation name
m_strClientName=lCase(m_objShell.ExpandEnvironmentStrings("%CLIENTNAME%"))
If InStr(m_strClientName,"CLIENTNAME") > 0 Or m_strClientName="" Then
	m_strClientName="unknown"
End If

'--get client workstation time
strYear=Year(Now())
strMonth=Month(Now()) : If strMonth < 10 Then strMonth="0" & strMonth
strDay=Day(Now()) : If strDay < 10 Then strDay="0" & strDay
strHour=Hour(Now()) : If strHour < 10 Then strHour="0" & strHour
strMinute=Minute(Now()) : If strMinute < 10 Then strMinute="0" & strMinute
m_strClientTime=strYear & "/" & strMonth & "/" & strDay & " " & strHour & ":" & strMinute

'--create sd_init logs folder if necessary 
If Not m_objFS.FolderExists("m:\scripts\logs") Then
	m_objFS.CreateFolder "m:\scripts\logs" 
End If
If Not m_objFS.FolderExists("m:\scripts\logs\sd_init") Then
	m_objFS.CreateFolder "m:\scripts\logs\sd_init" 
End If

'--get the command line argument if one was provided by an admin testing the script from the command line 
strArg=""
If WScript.Arguments.Count > 0 Then
	Set objArgs = WScript.Arguments
	If Err.Number > 0 Then DebugIt Err.Description
	strArg=Trim(objArgs(0))
End If

'--assign the lower case version of the user's logon name from the command line or the network object
If strArg <> vbNullString Then
	strLogonName=lCase(strArg)
Else
	strLogonName=lCase(m_objWshNetwork.UserName)
End If

'--get the APPDATA folder path
m_strAppDataPath=lCase(m_objShell.ExpandEnvironmentStrings("%APPDATA%"))
If Not m_objFS.FolderExists(m_strAppDataPath) Then
	m_strAppDataPath=""
End If

'--open a user-specific a log file ready if debug is enabled
If m_boolEnableDebug=true Then
	Set objLog=m_objFS.OpenTextFile("m:\scripts\logs\sd_init\" & strLogonName & ".log",FOR_APPEND,True)
End If

'--start the log entry
DebugIt "---------- Launch eCW Event ----------"
DebugIt "script_version: " & SCRIPT_VERSION 
DebugIt "cmd_argument: " & strArg
DebugIt "client_name: " & m_strClientName
DebugIt "logon_name: " & strLogonName
DebugIt "client_time: " & m_strClientTime
DebugIt "appdata: " & m_strAppDataPath

'--determine the site number
nNameLen=Len(strLogonName)
strSiteNumber="*"
If nNameLen >= 7 Then
	If Left(strLogonName,4)="site" Then
		strTemp=Mid(strLogonName,5,3) 
		If IsNumeric(strTemp) Then
			strSiteNumber=strTemp
		End If
	End If
End If
 
DebugIt "site_number: " & strSiteNumber

'--set the real root drive for the site folders
strRealRoot="m:\"
If m_objFS.FileExists("n:\SitesRealRoot_DoNotRemove.dat") Then
	strRealRoot="n:\"
End If

'--check for existence of the site folder on the ramdisk and change if appropriate
If m_objFS.FolderExists("r:\sites\" & strSiteNumber) Then
	strRealRoot="r:\"
End If

DebugIt "real_root: " & strRealRoot

'--set the sites folder
strSitesFolder="sites"
strTestFolder="eclinicalWorks"
DebugIt "sites_folder: " & strSitesFolder
DebugIt "test_folder: " & strTestFolder

'--set the assigned virtual root folder
If strSiteNumber = "*" Then
	strVirtualRoot=strRealRoot
Else
	strVirtualRoot=strRealRoot & strSitesFolder & "\" & strSiteNumber
End If
DebugIt "virtual_root: '" & strVirtualRoot & "'"
	
'--create a virtual drive c that maps to the site's virtual root directory
strCmd="subst c: " & strVirtualRoot
DebugIt "virtual_drive: executing '" & strCmd & "'"
Err.Clear
m_objShell.Run strCmd,0,True
If Trim(Err.Description) <> "" Then
	DebugIt "c_mapping: m_objShell.Run returned '" & Err.Description & "'"
End If

'--verify that the test folder now exists
boolDrvCExists=False
If m_objFS.FolderExists("c:\Program Files\" & strTestFolder) Then
	boolDrvC_Exists=True
	DebugIt "virtual_drive: 'subst' successful using virtual root; 'c:\Program Files\" & strTestFolder & "' exists"
Else
	DebugIt "virtual_drive: error: 'c:\Program Files\" & strTestFolder & "' does not exist after subst command"
End If

'--point the environment variables to the appropriate location (prefer R:, which is RAMDISK/SSD)
boolUseDriveR=False
If m_objFS.FolderExists("R:\") Then
	If Not m_objFS.FolderExists("R:\TEMP\" & strLogonName) Then
		Err.Clear
		m_objFS.CreateFolder("R:\TEMP\" & strLogonName)
		If Err.Number <> 0 Then
			DebugIt "r_temp_folder: error creating folder 'R:\TEMP\" & strLogonName & "': " & Err.Description
		Else
			DebugIt "r_temp_folder 'R:\TEMP\" & strLogonName & "': created"
			boolUseDriveR=True
		End If
	Else
		DebugIt "r_temp_folder: 'R:\TEMP\" & strLogonName & "' already exists"
		boolUseDriveR=True
	End If
Else
	DebugIt "r_drive: does not exist"
End If

'--ensure that folder 'c:\temp' exists if appropriate
If boolDrvC_Exists Then
	If Not m_objFS.FolderExists("c:\Temp") Then
		Err.Clear
		m_objFS.CreateFolder("c:\Temp")
		If Err.Description <> vbBullString Then
			DebugIt "temp_folder: error, could not create 'c:\temp'. [" & Err.Description & "]"
		Else
			DebugIt "temp_folder: successfully created 'c:\Temp'"
		End if
	Else
		DebugIt "temp_folder: 'c:\temp' already exists"
	End if
End If

'--do any custom drive H mappings
strSQL="select unc_path from drive_mappings where siteid='" & strSiteNumber & "' limit 1;"
strCustomUNCPath=PopRecord(QueryControlData(strSQL))
If strCustomUNCPath <> vbNullString Then
	If Not m_objFS.DriveExists("h:") Then
		Err.Clear
		m_objWshNetwork.MapNetworkDrive "h:",strCustomUncPath
		If Err.Number = 0 Then
			DebugIt "custom_mapping: drive h: mapped to " & strCustomUncPath
		Else
			DebugIt "custom_mapping: m_objWshNetwork.MapNetworkDrive returned error '" & Err.Description & "'"
		End If
	Else
		DebugIt "custom mapping: drive h: already exists"
	End If
Else
	DebugIt "custom_mapping: none"
End If

'--create app data psm folder if necessary
If Not m_objFS.FolderExists(m_strAppDataPath & "\psm") Then
	m_objFS.CreateFolder(m_strAppDataPath & "\psm")
End If

'--check for existence of registry init flag file
m_strInitFlagFile=m_strAppDataPath & "\psm\_init_" & strLogonName
If Not m_objFS.FileExists(m_strInitFlagFile) Then

	'--init the registry settings for this user profile
	InitRegistrySettings

	'--create the flag file so we don't do it again next time fot this same user
	Set objInitFlagFile=m_objFS.OpenTextFile(m_strInitFlagFile,FOR_WRITE,True)
	Set objInitFlagFile=Nothing
Else
	DebugIt "registry init flag file '" & m_strInitFlagFile & "' exists; skipping registry initialization"
End If

'--release the objects and quit
Set m_objShell=Nothing
Set m_objFS=Nothing
Set m_objWshNetwork=Nothing
Wscript.Quit


'#####################################################
'##                                                 ##
'##               subs and functions                ##
'##                                                 ##
'#####################################################

Sub DebugIt(strText)

	'--if debug is disabled, don't log anything
	If m_boolEnableDebug=false Then
		Exit Sub
	End If

	'--get system time
	Set objWMIService = GetObject("winmgmts:\\" & m_strComputer & "\root\cimv2")
	Set colItems = objWMIService.ExecQuery("Select * From Win32_LocalTime")
	For Each objItem in colItems
		strMonth=objItem.Month : If strMonth < 10 Then strMonth="0" & strMonth
		strDay=objItem.Day : If strDay < 10 Then strDay="0" & strDay
		strHour=objItem.Hour : If strHour < 10 Then strHour="0" & strHour
		strMinute=objItem.Minute : If strMinute < 10 Then strMinute="0" & strMinute
    		m_strServerTime=objItem.Year & "/" & strMonth & "/" & strDay & " " & strHour & ":" & strMinute
	Next

	'--record the event
 	Err.Clear
	If Not objLog Is Nothing Then
 		objLog.WriteLine m_strServerTime & " - " & strText
 		If Err.Number <> 0 Then
			strMsg="Non-critical warning: Unable to write to the logon log file. ('" & Err.Description & "')"
			If m_objShell is Nothing Then
				Wscript.Echo strMsg
			Else
				ntButton = m_objShell.Popup(strMsg,,"Init Script Version: " & SCRIPT_VERSION,48)
			End If
 		End If
	Else
		ntButton = m_objShell.Popup(strText,,"Init Script Version: " & SCRIPT_VERSION,48)
	End If

End Sub

Function QueryControlData(strSQL)
	strRS=vbNullString
	strRecord=vbNullString
	strCmd="""M:\Program Files\MySQL\MySQL Server 5.1\bin\mysql.exe""" & _
		" -hvirtdb03 -P5000 -uroot -pzrt+Axj23 -Dcontrol_data -e""" & strSQL & """ -s --skip-column-names"
	Set objExec=m_objShell.Exec(strCmd)
	Do While Not objExec.StdOut.AtEndOfStream 
		strRecord=objExec.StdOut.ReadLine & vbCrLf
		strRS=strRS & strRecord
	Loop
	QueryControlData=strRS
End Function

Function PopRecord(strRS)
	intPos=Instr(strRS,vbCrLf)
	If intPos > 0 Then
		strRec=Left(strRS,intPos-1)
		strRS=Right(strRS,Len(strRS)-intPos)
	End If
	PopRecord=Replace(strRec,"\\","\")
End Function

Sub InitRegistrySettings()

	'--use shell.regwrite to set acrobat reader registry entries to prevent high CPU issue
	DebugIt "registry: adding adobe reader keys to prevent high cpu"
	m_objShell.RegWrite "HKCU\Software\Adobe\Acrobat Reader\10.0\IPM\bShowMsgAtLaunch",0,"REG_DWORD"
	m_objShell.RegWrite "HKCU\Software\Adobe\Acrobat Reader\10.0\IPM\bDontShowMsgWhenViewingDoc",1,"REG_DWORD"
	m_objShell.RegWrite "HKCU\Software\Adobe\Acrobat Reader\11.0\IPM\bShowMsgAtLaunch",0,"REG_DWORD"
	m_objShell.RegWrite "HKCU\Software\Adobe\Acrobat Reader\11.0\IPM\bDontShowMsgWhenViewingDoc",1,"REG_DWORD"

	'--use shell.regwrite to set certificate revocation registry keys to prevent pop-up in eCW
	DebugIt "registry: disable checking for certificate revocation"
	m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\CertificateRevocation",0,"REG_DWORD"

	'--create the registry access object for the remainder of the registry work
	Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\default:StdRegProv")

	'--redirect temporary files if appropriate
	If boolUseDriveR Then

		DebugIt "registry: redirecting temporary files"

		'temporary internet files
		m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\Cache","R:\IECache\" & strLogonName,"REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Cache\Directory","R:\IECache\" & strLogonName,"REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\Cache","R:\IECache\" & strLogonName,"REG_SZ"

		'history
		m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\History","R:\IEHistory\" & strLogonName,"REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\History","R:\IEHistory\" & strLogonName,"REG_SZ"

		'temp directory
		m_objShell.RegWrite "HKCU\Environment\TEMP","R:\TEMP\" & strLogonName,"REG_SZ"
		m_objShell.RegWrite "HKCU\Environment\TMP","R:\TEMP\" & strLogonName,"REG_SZ"

	End If

	'--change IE cache to download on every visit to the page
	strKeyPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
	strValueName = "SyncMode5"
	dwValue = 3
	Err.Clear
	objReg.SetDWORDValue HKEY_CURRENT_USER, strKeyPath, strValueName, dwValue
	If Err.Number > 0 Then
		DebugIt "registry: ie cache syncmode: error when setting registry: " & Err.Description
	Else
		DebugIt "registry: ie cache syncmode: changed to 3 (check on every visit)"
	End If

	'--change the registry to make explorer browse folders in the same window
	strKeyPath= "Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState"
	sValue=vbNull
	strValueName = "Settings"
	objReg.GetBinaryValue HKEY_CURRENT_USER,strKeyPath,strValueName,sValue
	If Not isNull(sValue) Then
		For i = lBound(sValue) to uBound(sValue)
			strValue=strValue & sValue(i) & " "
			byteX=CByte(sValue(i))
			Redim Preserve byteArray(i)
			If i=4 Then
				If byteX > 32 Then
					byteArray(i)=byteX-32
				Else
					byteArray(i)=byteX
				End If
			Else
				byteArray(i)=byteX
			End If
		Next
		For i=lBound(byteArray) To uBound(byteArray)
			strValue2=strValue2 & CStr(byteArray(i)) & " "
		Next 
		DebugIt "registry: explorer value 1: " & strValue
		DebugIt "registry: explorer value 2: " & strValue2
		If strValue <> strValue2 Then
			nReturn = objReg.SetBinaryValue(HKEY_CURRENT_USER, _
   				strKeyPath, _
   				strValueName, _
   				byteArray)
			If (nReturn <> 0) Or (Err.Number <> 0) Then
    				DebugIt "registry: explorer_change: fail"
			Else
   				DebugIt "registry: explorer_change: success"
			End If
		Else
			DebugIt "registry: explorer_change: skipped"
		End if
	Else
		DebugIt "registry: explorer_change: fail (GetBinaryValue returned null)"
	End If

	'--initialize IE page setup settings if appropriate
	strKeyPath = "Software\Microsoft\Internet Explorer\PageSetup"
	strValueName = "Shrink_To_Fit"
	objReg.GetStringValue HKEY_CURRENT_USER,strKeyPath,strValueName,strValue
	If IsNull(strValue) Then
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\footer","&u&b&d","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\header","&w&bPage &p of &P","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\margin_bottom","0.750000","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\margin_left","0.750000","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\margin_right","0.750000","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\margin_top","0.750000","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\Print_Background","no","REG_SZ"
		m_objShell.RegWrite "HKCU\Software\Microsoft\Internet Explorer\PageSetup\Shrink_To_Fit","yes","REG_SZ"
		DebugIt "registry: ie page setup initialized"
	Else
		DebugIt "registry: ie page setup is already configured"
	End If

	'--release the registry object
	Set objReg=Nothing
	
End Sub


'EOF
