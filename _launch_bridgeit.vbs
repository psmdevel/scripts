'--set vars
m_boolQuit=false
m_strCmd="""M:\Program Files (x86)\Microsoft Office\Office14\MSACCESS.EXE""" 

'--create the objects
Set m_objNet=CreateObject("Wscript.Network")
Set m_objShell=CreateObject("Wscript.Shell")
Set m_objFs=CreateObject("Scripting.FileSystemObject")

'--get the logon account name
m_strLogonName=lCase(m_objNet.UserName)

'--extract the site number
If Len(m_strLogonName) >= 7 Then
	If Left(m_strLogonName,4)="site" Then
		m_strSiteNumber=Mid(m_strLogonName,5,3)
		If Not IsNumeric(m_strSiteNumber) Then
			MsgBox "No site number detected."
			m_boolQuit=True
		End If
	End If
Else
	MsgBox "No Bridge-IT configuration available for your account type."
	m_boolQuit=True
End If

'--check for MDB files
m_strMDBFile="\\Brit01\sites\" & m_strSiteNumber & "\toolbox\" & m_strLogonName & "\" & m_strLogonName & "-2010.mdb"
If Not m_ObjFs.FileExists(m_strMDBFile) Then
	MsgBox "No Bridge-IT configuration exists for your user account, " & m_strLogonName & "."
	m_boolQuit=True
End If

'--quit if appropriate
If m_boolQuit=True Then
	Wscript.Quit
End If


'--open bridge-it
m_strArgs=m_strMDBFile & " /wrkgrp \\Brit01\bridgeitecw\netinfo\fdi.mdw"
m_objShell.Run m_strCmd & " " & m_strArgs

