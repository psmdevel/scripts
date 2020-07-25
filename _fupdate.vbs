On Error Resume Next

'-create objects
Set m_objShell=CreateObject("Wscript.Shell")
Set m_objFS=CreateObject("Scripting.FileSystemObject")
Set m_objNet=CreateObject("Wscript.Network")

'--Load the function library
If LoadLibrary <> 0 Then 
	Wscript.Echo "failed to load the function library"
	Wscript.Quit
End If

'--set log destinations
m_strLogDests="console"

'--init vars
m_boolHelp=False
m_boolBadArg=False
m_strFileName=""
m_strAction=""
m_strTargetType=""
m_strMyHostName=lCase(m_objNet.ComputerName)

'--overrides
m_boolEnableDebug=False

'--process arguments
Set m_objArgs=Wscript.Arguments
For intCount=0 To m_objArgs.Count - 1
	strArg=m_objArgs(intCount)
	intPos=Instr(strArg,":")
	If intPos > 0 Then 
		strLeft=Trim(Left(strArg,intPos-1))
		strRight=Trim(Right(strArg,Len(strArg)-intPos))
	Else
		strLeft=Trim(strArg)
		strRight=""
	End If
	Select Case strLeft
		Case "--help","-h"
			m_boolHelp=True
		Case "--file","-f"
			m_strFileName=strRight
		Case "--action","-a"
			m_strAction=lCase(strRight)				
		Case "--type","-t"
			m_strTargetType=lCase(strRight)				
		Case Else
			m_boolBadArg=True
			Exit For
	End Select
Next

'--help
If m_boolHelp=True Then
	ShowUsage
	Wscript.Quit
End If

'--sanity checks
If m_strFileName="" Then
	LogIt "must specify a file name"
	Wscript.Quit
Else
	If Not m_objFS.FileExists(m_strFileName) Then
		If m_strAction <> "d" Then
				LogIt "file '" & m_strFileName & "' does not exist locally"
				Wscript.Quit
		End If
	End If
End If
If m_strAction="" Then
	LogIt "must specify an action"
	Wscript.Quit
Else
	If Instr("a|r|d|t",m_strAction)=0 Then
		LogIt "unknown action"
		Wscript.Quit
	End If
End If
If m_strTargetType="" Then 
	m_strTargetType="**"
End If
boolGoodType=False
If Len(m_strTargetType)=2 Then
	If Instr("ts|la|pa|mg|br|ms|cw|od|dc|ap|**",m_strTargetType) > 0 Then
		boolGoodType=True
	End if
End If
If Not boolGoodType Then
	LogIt "unknown type"
	Wscript.Quit
End If

'--set the local script path
m_strLocalScriptFolder=""
If m_objFS.FolderExists("c:\scripts") Then
	m_strLocalScriptFolder="c:\scripts"
Else
	If m_objFS.FolderExists("m:\scripts") Then
		m_strLocalScriptFolder="m:\scripts"
	End If
End If
If m_strLocalScriptFolder="" Then
	LogIt "could not detect a local scripts folder"
	Wscript.Quit
End If

'--set the control data connection string
m_strControlDataConnStr=SetControlDataConnStr
If m_strControlDataConnStr=vbNullString Then
	LogIt "could not establish a control string for the control_data database"
	Wscript.Quit
End If

'--get the list of windows servers that match the target type"
strSQL="select hostname from servers where os='w' "
If m_strTargetType="**" Then
	strSQL=strSQL & "order by hostname;"
Else
	strSQL=strSQL & "and hostname like '" & m_strTargetType & "%' order by hostname;"
End If
m_strRS=DbQuery(strSQL,m_strControlDataConnStr)

'--display the local file
m_strLocalFileSpec=m_strLocalScriptFolder & "\" & m_strFileName
Set objFile=m_objFS.GetFile(m_strLocalFileSpec)
strOutput="Local file: " & m_strLocalFileSpec & " - " & MakeTimeStamp(objFile.DateLastModified)
Set objFile=Nothing
Wscript.Echo 
LogIt strOutput
LogIt ""

'--loop through the array and perform the action
For nCounter=0 To uBound(m_strRS)

	'--set the remote server name
	strRemoteServer=Trim(lCase(m_strRS(nCounter)))

	'--start with an empty remote scripts folder
	m_strRemoteScriptFolder=""

	'--set the UNC path
	strUNC="\\" & strRemoteServer
	If m_objFS.FolderExists(strUNC & "\c$\scripts") Then
		m_strRemoteScriptFolder=strUNC & "\c$\scripts"
	End If
	If m_objFS.FolderExists(strUNC & "\m$\scripts") Then
		m_strRemoteScriptFolder=strUNC & "\m$\scripts"
	End If

	'--set the display spacer length
	nSpacer=8-Len(strRemoteServer)

	'--start the output
	strOutput=strRemoteServer & ": " & Space(nSpacer) & m_strFileName & " "
	
	If m_strRemoteScriptFolder = "" Then
	
		strOutPut=strOutPut & vbTab & "(no scripts folder)"
		LogIt strOutPut		
	
	Else
	
		'--perform the action
		Select Case m_strAction
		
			Case "a"
				m_strRemoteFileSpec=m_strRemoteScriptFolder & "\" & m_strFileName
				If Not m_objFS.FileExists(m_strRemoteFileSpec) Then
					If m_objFS.FileExists(m_strLocalFileSpec) Then
						Err.Clear
						m_objFS.CopyFile m_strLocalFileSpec,m_strRemoteFileSpec
						If Err.Number > 0 Then
							strOutPut=strOutPut & vbTab & "(error: " & Err.Description & ")"
						Else
							strOutPut=strOutPut & vbTab & "added"
						End If
					End If
				Else
					strOutPut=strOutPut & vbTab & "(already exists)"
				End If
				LogIt strOutPut

			Case "t"
				m_strRemoteFileSpec=m_strRemoteScriptFolder & "\" & m_strFileName
				If m_objFS.FileExists(m_strRemoteFileSpec) Then
					Set objFile=m_objFS.GetFile(m_strRemoteFileSpec)
					strOutput=strOutput & vbTab & MakeTimeStamp(objFile.DateLastModified)
					Set objFile=Nothing
				Else
					strOutput=strOutput & vbTab & "(not found)"
				End If
				If Instr(strUNC,m_strMyHostName) > 0 Then
					strOutput=strOutput & " [local]"
				End If
				LogIt strOutput
				
			Case "r"
				m_strRemoteFileSpec=m_strRemoteScriptFolder & "\" & m_strFileName
				If m_objFS.FileExists(m_strRemoteFileSpec) Then
					If m_objFS.FileExists(m_strLocalFileSpec) Then
						Err.Clear
						m_objFS.CopyFile m_strLocalFileSpec,m_strRemoteFileSpec
						If Err.Number > 0 Then
							strOutPut=strOutPut & vbTab & "(error: " & Err.Description & ")"
						Else
							strOutPut=strOutPut & vbTab & "replaced"
						End If
					End If
				Else
					strOutPut=strOutPut & vbTab & "(not found)"
				End If
				LogIt strOutPut

			Case "d"
				m_strRemoteFileSpec=m_strRemoteScriptFolder & "\" & m_strFileName
				If m_objFS.FileExists(m_strRemoteFileSpec) Then
					m_objFS.DeleteFile m_strRemoteFileSpec
					If Err.Number > 0 Then
						strOutPut=strOutPut & vbTab & "(error: " & Err.Description & ")"
					Else
						strOutPut=strOutPut & vbTab & "deleted"
					End If
				Else
					strOutPut=strOutPut & vbTab & "(not found)"
				End If
				LogIt strOutPut

		End Select

	End If

Next

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

Function MakeTimeStamp(datDate)
	strMonth=Month(datDate):If Len(strMonth) < 2 Then strMonth="0" & strMonth
	strDay=Day(datDate):If Len(strDay) < 2 Then strDay="0" & strDay
	strYear=Year(datDate)
	strTime=FormatDateTime(datDate,4)
	MakeTimeStamp=strMonth & "/" & strDay & "/" & strYear & " " & strTime	
End Function

Sub LogIt (strMsg)
	Logger strMsg,m_strLogDests
End Sub

Sub ShowUsage()
	Wscript.Echo "Usage: fupdate <options>"
	Wscript.Echo ""
	Wscript.Echo "Options:"
	Wscript.Echo ""
	Wscript.Echo vbTab & "-h|--help"
	Wscript.Echo vbTab & "-f|--file:<file>"
	Wscript.Echo vbTab & "-a|--action:<[a|r|d|t]>"
	Wscript.Echo vbTab & "-t|--type:<[ts|la|pa|mg|br|ms|cw|od|dc|ap]>"
End Sub