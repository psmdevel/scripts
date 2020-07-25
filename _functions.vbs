'--this is an include file to be used by other scripts

'--set constants
Const HKEY_LOCAL_MACHINE = &H80000002
'Const LOG_SUCCESS=0
'Const LOG_ERROR=1
'Const LOG_WARNING=2
'Const LOG_INFORMATION=4
'Const LOG_AUDIT_SUCCESS=8
'Const LOG_AUDIT_FAILURE=16

'--set variables
Dim g_strPossibleControlHosts(1)
Dim g_strPossibleDbUsers(1)
g_strControlDataMaster="dbclust11"
g_strControlDataSlave="dbclust12"
g_strPossibleControlHosts(0)=g_strControlDataMaster
g_strPossibleControlHosts(1)=g_strControlDataSlave
g_strComputer="."
g_strRecDelim=Chr(30)
g_strFieldDelim=Chr(31)
g_strPossibleDbUsers(0)="root"
g_strPossibleDbUsers(1)="root_sa"
g_strControlDataHost=""
g_strControlDataUser=""
g_strControlDataPort=5000

Function GetOdbcDriversList()
	Dim strDriverList()
	Redim strDriverList(0)
	Set objReg = GetObject("winmgmts:\\" & g_strComputer & "\root\default:StdRegProv")
	strKeyPath = "SOFTWARE\ODBC\ODBCINST.INI\ODBC Drivers"
	objReg.EnumValues HKEY_LOCAL_MACHINE, strKeyPath, strValueNames, strValueTypes
	For nIndex = 0 to uBound(strValueNames)
		strValueName = strValueNames(nIndex)
		objReg.GetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
		strDriver=strValueNames(nIndex)
		If Instr(strDriver,"MySQL") Then
			If strDriverList(0) <> vbNullString Then
				Redim Preserve strDriverList(uBound(strDriverList)+1)
			End If
			strDriverList(uBound(strDriverList))=strDriver
		End If
	Next
	Set objReg=Nothing
	GetOdbcDriversList=strDriverList
End Function

Sub Logger(strMsg,strMsgDests)
		
	strMsgDests=Trim(strMsgDests)
	If strMsgDests=vbNullString Then
		Exit Sub
	End If
	If Left(strMsg,6)="debug:" Then
		If m_boolEnableDebug=False Then
			Exit Sub
		End If
	End If
	strDestArray=Split(strMsgDests,"+")
	For nIndex=0 To uBound(strDestArray)
		strDest=lCase(strDestArray(nIndex))
		Select Case strDest
			Case "console"
				Wscript.Echo "~: " & strMsg
			Case "log"
				If m_strLogFile <> vbNullString Then
					If Not m_objFS Is Nothing Then
						Set objLog=m_objFS.OpenTextFile(m_strLogFile,8,True)
						objLog.WriteLine Now() & ": " & strMsg
						Set objLog=Nothing
					End If
				End If			
			Case "event"
				If Left(strMsg,9)="win_event" Then
					If Not m_objShell Is Nothing Then
						m_objShell.LogEvent LOG_INFORMATION, strMsg
					End If					
				End If
		End Select
	Next
End Sub

Function SetSiteConnStr(strDbCluster,strSID)
	LogIt "debug: entered: SetSiteConnStr()"
	SetSiteConnStr=""
	
	If Not IsDbListening(strDbCluster,strSID) Then
		LogIt "debug: server " & strDbCluster & " is not listening for site " & strSID
		LogIt "debug: exiting SetSiteConnStr()"
		Exit Function
	End If
	
	'--get the list of drivers
	m_strDriverArray=GetOdbcDriversList()
	
	'loop through the possible drivers
	For nIndex=0 To uBound(m_strDriverArray)
		strConnStrPt1="DRIVER={" & m_strDriverArray(nIndex) & "}; SERVER=" & strDbCluster & "; PORT=5" & strSID & "; DATABASE=mobiledoc_" & strSID & "; " 		

			'-loop through the possible users
			For nIndex2=0 To uBound(g_strPossibleDbUsers)
				strConnStrPt2="UID=" & g_strPossibleDbUsers(nIndex2) & ";PASSWORD=" & Auth & "; OPTION=3; "

				'--assemble the connection string
				strConnStr=strConnStrPt1 & strConnStrPt2
				
				'--test the connection string
				strRS=DbQuery("select version();",strConnStr)
				
				'--if success, exit
				strVersion=strRS(0)
				If strVersion <> vbNullString Then
					SetSiteConnStr=strConnStr
					LogIt "debug: exiting: SetSiteConnStr()"
					Exit Function
				End If
			Next			
	Next
	SetSiteConnStr=""
	LogIt "debug: exiting: SetSiteConnStr()"	
End Function

Function SetControlDataConnStr()
	LogIt "debug: entered SetControlDataConnStr()"
	'--get the list of drivers
	m_strDriverArray=GetOdbcDriversList()
	
	'loop through the possible drivers
	For nIndex=0 To uBound(m_strDriverArray)
		strConnStrPt1="DRIVER={" & m_strDriverArray(nIndex) & "}; " 		

		'-loop through the possible servers
		For nIndex2=0 To uBound(g_strPossibleControlHosts)	
			strConnStrPt2="SERVER=" & g_strPossibleControlHosts(nIndex2) & "; PORT=" & g_strControlDataPort & "; DATABASE=control_data;"

			'-loop through the possible users
			For nIndex3=0 To uBound(g_strPossibleDbUsers)
				strConnStrPt3="UID=" & g_strPossibleDbUsers(nIndex3) & ";PASSWORD=" & Auth & "; OPTION=3; "

				'--assemble the connection string
				strConnStr=strConnStrPt1 & strConnStrPt2 & strConnStrPt3
				
				'--test the connection string
				strRS=DbQuery("select version();",strConnStr)
				
				'--if success, exit
				strVersion=strRS(0)
				If strVersion <> vbNullString Then
					LogIt "debug: SUCCESS!"
					SetControlDataConnStr=strConnStr
					LogIt "debug: exiting SetControlDataConnStr()"
					Exit Function
				End If
			Next			
		Next
	Next
	LogIt "debug: exiting SetControlDataConnStr()"
	SetControlDataConnStr=""
End Function

Function DbQuery(strSQL, strConnString)
	LogIt "debug: entered: DbQuery()"
	LogIt "debug: strSQL=" & strSQL
	On Error Resume Next

	Dim objConn
	Dim objRS 
	Dim strRS
	Redim strRS(0)
	
	'--set return to an empty array initially
	DbQuery=strRS
			
	'create an instance of the ADO connection and recordset objects
	Set objConn = Wscript.CreateObject("ADODB.Connection")
	Set objRS = Wscript.CreateObject("ADODB.Recordset")

	'--open a connection to the database
	Err.Clear
	LogIt "debug: execute: objConn.Open " & strConnString
	objConn.ConnectionTimeout=3
	objConn.Open strConnString
	Set colErrors=objConn.Errors
	For Each objError in colErrors
		LogIt "debug: ado_connection: " & objError.Description
	Next
	If Err.Number > 0 Then
		LogIt "debug: error: " & Err.Description
	End If
	Err.Clear
	Set colErrors=Nothing
	
	'--if the connection failed to open, exit the function
	LogIt "debug: objConn.State=" & objConn.State
	If objConn.State <> 1 Then
		LogIt "debug: exiting: DbQuery()"
		Exit Function
	End If

	'--connection opened, now open the recordset
	Err.Clear
	LogIt "debug: executing: objRS.Open"
	objRS.Open strSQL,objConn
	Set colErrors=objConn.Errors
	For Each objError in colErrors
		LogIt "debug: ado_recordset: " & objError.Description
	Next
	Set colErrors=Nothing
	If Err.Number > 0 Then
		LogIt "debug: error: " & Err.Number & "(" & Err.Description & ")"
		LogIt "debug: exiting DbQuery()"
		Exit Function
	End If
	If objRS.State <> 1 Then
		LogIt "debug: objRS failed to open" & Err.Description
		LogIt "debug: exiting DbQuery()"
		Exit Function
	End If
	
	'--process the recordset
	nRecCount=0
	If Not (objRS.BOF And objRS.EOF) Then
	
		'--increment the record count
		nRecCount=nRecCount+1
		
		'--get the field count
		nFieldCount=objRS.Fields.Count
		LogIt "debug: nFieldCount=" & nFieldCount
		
		'--loop through the objRS and add the records with field delims
		objRS.MoveFirst
		Do While Not objRS.EOF
			strRec=vbNullString
			For nIndex=0 To nFieldCount-1
				strField=objRS.Fields(nIndex)
				LogIt "debug: strField=" & strField
				If strRec=vbNullString Then	
					strRec=strField
				Else
					strRec=strRec & strField
				End If
				If nIndex < nFieldCount-1 Then
					strRec=strRec & g_strFieldDelim
				End If
			Next
			If strRS(0) <> vbNullString Then
				Redim Preserve strRS(uBound(strRS)+1)
			End If
			strRS(uBound(strRS))=strRec
			objRS.MoveNext
		Loop
	Else
		LogIt "debug: no records returned"
	End If
	LogIt "debug: nRecCount=" & nRecCount
	LogIt "debug: uBound(strRS)=" & uBound(strRS)
	LogIt "debug: strRS(0)=" & strRS(0)

	'--close recordset object 
	objRS.Close
		
	'--destroy objects
	Set objRS=nothing
	Set objConn=nothing
	Set colErrors=Nothing		
	
	'--return the array
	DbQuery=strRS
	
	On Error Goto 0
	LogIt "debug: exiting: DbQuery()"

End Function

Function DbExecute(strSQL, strConnString)
	LogIt "debug: entered: DbExecute()"
	On Error Resume Next

	Dim objConn
		
	'create an instance of the ADO connection and recordset objects
	Set objConn = Wscript.CreateObject("ADODB.Connection")
	Set objRS = Wscript.CreateObject("ADODB.Recordset")

	'--open a connection to the database
	Err.Clear
	LogIt "debug: objConn.Open " & strConnString
	objConn.ConnectionTimeout=3
	objConn.Open strConnString
	Set colErrors=objConn.Errors
	For Each objError in colErrors
		LogIt "debug: ado_connection: " & objError.Description
	Next
	If Err.Number > 0 Then
		LogIt "debug: error: " & Err.Description
	End If
	Err.Clear
	Set colErrors=Nothing
	
	'--if the connection failed to open, exit the function
	LogIt "debug: objConn.State=" & objConn.State
	If objConn.State <> 1 Then
		LogIt "debug: exiting: DbExecute()"
		DbExecute=1
		Exit Function
	End If

	'--connection opened, now execute the SQL
	Err.Clear
	LogIt "debug: objConn.Execute"
	LogIt "debug: strSQL=" & strSQL
	objConn.Execute(strSQL)
	Set colErrors=objConn.Errors
	For Each objError in colErrors
		LogIt "debug: ado_connection: " & objError.Description
	Next
	Set colErrors=Nothing
	If Err.Number > 0 Then
		LogIt "debug: error: " & Err.Number & "(" & Err.Description & ")"
		LogIt "debug: exiting DbExecute()"
		DbExecute=1
		Exit Function
	End If
	
	'--destroy objects
	Set objConn=nothing
	Set colErrors=Nothing		
	
	'--return the array
	DbExecute=0
	
	On Error Goto 0
	LogIt "debug: exiting: DbExecute()"

End Function

Function IsDbListening(strServer,strSID)
	strPort="5" & strSID
	IsDbListening=False
	strCmd="tcping -n 1 " & strServer & " " & strPort
	LogIt "debug: strCmd=" & strCmd
	Set objExec=m_objShell.Exec(strCmd)
	Do While Not objExec.StdOut.AtEndOfStream
		strLine=Trim(objExec.StdOut.ReadLine)
		If strLine <> "" Then
			LogIt "debug: strLine=" & strLine
			If Instr(strLine,"1 successful") > 0 Then
				IsDbListening=True
				Exit Do
			End If
		End If
	Loop
End Function

Function Auth()
	Auth="zrt+Axj23"
End Function

