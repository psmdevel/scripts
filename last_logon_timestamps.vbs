' LastLogon.vbs
' VBScript program to determine when each user in the domain last logged
' on.
'
' ----------------------------------------------------------------------
' Copyright (c) 2002-2010 Richard L. Mueller
' Hilltop Lab web site - http://www.rlmueller.net
' Version 1.0 - December 7, 2002
' Version 1.1 - January 17, 2003 - Account for null value for lastLogon.
' Version 1.2 - January 23, 2003 - Account for DC not available.
' Version 1.3 - February 3, 2003 - Retrieve users but not contacts.
' Version 1.4 - February 19, 2003 - Standardize Hungarian notation.
' Version 1.5 - March 11, 2003 - Remove SearchScope property.
' Version 1.6 - May 9, 2003 - Account for error in IADsLargeInteger
'                             property methods HighPart and LowPart.
' Version 1.7 - January 25, 2004 - Modify error trapping.
' Version 1.8 - July 6, 2007 - Modify how IADsLargeInteger interface
'                              is invoked.
' Version 1.9 - December 29, 2009 - Output "Never" if no date.
' Version 1.10 - November 6, 2010 - No need to set objects to Nothing.
'
' Because the lastLogon attribute is not replicated, every Domain
' Controller in the domain must be queried to find the latest lastLogon
' date for each user. The lastest date found is kept in a dictionary
' object. The program first uses ADO to search the domain for all Domain
' Controllers. The AdsPath of each Domain Controller is saved in an
' array. Then, for each Domain Controller, ADO is used to search the
' copy of Active Directory on that Domain Controller for all user
' objects and return the lastLogon attribute. The lastLogon attribute is
' a 64-bit number representing the number of 100 nanosecond intervals
' since 12:00 am January 1, 1601. This value is converted to a date. The
' last logon date is in UTC (Coordinated Univeral Time). It must be
' adjusted by the Time Zone bias in the machine registry to convert to
' local time.
'
' You have a royalty-free right to use, modify, reproduce, and
' distribute this script file in any way you find useful, provided that
' you agree that the copyright owner above has no warranty, obligations,
' or liability for such use.

Option Explicit

Dim objFS
Dim objOutFile
Set objFS=CreateObject("Scripting.FileSystemObject")
Set objOutFile=objFS.OpenTextFile("LastLogonTimeStamps.txt",2,True)

Dim objRootDSE, strConfig, adoConnection, adoCommand, strQuery
Dim adoRecordset, objDC
Dim strDNSDomain, objShell, lngBiasKey, lngBias, k, arrstrDCs()
Dim strDN, dtmDate, objDate, objList, strUser
Dim strBase, strFilter, strAttributes, lngHigh, lngLow

' Use a dictionary object to track latest lastLogon for each user.
Set objList = CreateObject("Scripting.Dictionary")
objList.CompareMode = vbTextCompare

' Obtain local Time Zone bias from machine registry.
' This bias changes with Daylight Savings Time.
Set objShell = CreateObject("Wscript.Shell")
lngBiasKey = objShell.RegRead("HKLM\System\CurrentControlSet\Control\" _
    & "TimeZoneInformation\ActiveTimeBias")
If (UCase(TypeName(lngBiasKey)) = "LONG") Then
    lngBias = lngBiasKey
ElseIf (UCase(TypeName(lngBiasKey)) = "VARIANT()") Then
    lngBias = 0
    For k = 0 To UBound(lngBiasKey)
        lngBias = lngBias + (lngBiasKey(k) * 256^k)
    Next
End If

' Determine configuration context and DNS domain from RootDSE object.
Set objRootDSE = GetObject("LDAP://RootDSE")
strConfig = objRootDSE.Get("configurationNamingContext")
strDNSDomain = objRootDSE.Get("defaultNamingContext")

' Use ADO to search Active Directory for ObjectClass nTDSDSA.
' This will identify all Domain Controllers.
Set adoCommand = CreateObject("ADODB.Command")
Set adoConnection = CreateObject("ADODB.Connection")
adoConnection.Provider = "ADsDSOObject"
adoConnection.Open "Active Directory Provider"
adoCommand.ActiveConnection = adoConnection

strBase = "<LDAP://" & strConfig & ">"
strFilter = "(objectClass=nTDSDSA)"
strAttributes = "AdsPath"
strQuery = strBase & ";" & strFilter & ";" & strAttributes & ";subtree"

adoCommand.CommandText = strQuery
adoCommand.Properties("Page Size") = 100
adoCommand.Properties("Timeout") = 60
adoCommand.Properties("Cache Results") = False

Set adoRecordset = adoCommand.Execute

' Enumerate parent objects of class nTDSDSA. Save Domain Controller
' AdsPaths in dynamic array arrstrDCs.
k = 0
Do Until adoRecordset.EOF
    Set objDC = _
        GetObject(GetObject(adoRecordset.Fields("AdsPath").Value).Parent)
    ReDim Preserve arrstrDCs(k)
    arrstrDCs(k) = objDC.DNSHostName
    k = k + 1
    adoRecordset.MoveNext
Loop
adoRecordset.Close

' Retrieve lastLogon attribute for each user on each Domain Controller.
For k = 0 To Ubound(arrstrDCs)
    strBase = "<LDAP://" & arrstrDCs(k) & "/" & strDNSDomain & ">"
    strFilter = "(&(objectCategory=person)(objectClass=user))"
    strAttributes = "distinguishedName,lastLogon"
    strQuery = strBase & ";" & strFilter & ";" & strAttributes _
        & ";subtree"
    adoCommand.CommandText = strQuery
    On Error Resume Next
    Set adoRecordset = adoCommand.Execute
    If (Err.Number <> 0) Then
        On Error GoTo 0
        Wscript.Echo "Domain Controller not available: " & arrstrDCs(k)
    Else
        On Error GoTo 0
        Do Until adoRecordset.EOF
            strDN = adoRecordset.Fields("distinguishedName").Value
            On Error Resume Next
            Set objDate = adoRecordset.Fields("lastLogon").Value
            If (Err.Number <> 0) Then
                On Error GoTo 0
                dtmDate = #1/1/1601#
            Else
                On Error GoTo 0
                lngHigh = objDate.HighPart
                lngLow = objDate.LowPart
                If (lngLow < 0) Then
                    lngHigh = lngHigh + 1
                End If
                If (lngHigh = 0) And (lngLow = 0) Then
                    dtmDate = #1/1/1601#
                Else
                    dtmDate = #1/1/1601# + (((lngHigh * (2 ^ 32)) _
                        + lngLow)/600000000 - lngBias)/1440
                End If
            End If
            If (objList.Exists(strDN) = True) Then
                If (dtmDate > objList(strDN)) Then
                    objList.Item(strDN) = dtmDate
                End If
            Else
                objList.Add strDN, dtmDate
            End If
            adoRecordset.MoveNext
        Loop
        adoRecordset.Close
    End If
Next

' Output latest lastLogon date for each user.
For Each strUser In objList.Keys
    If (objList.Item(strUser) = #1/1/1601#) Then
        Wscript.Echo strUser & ";Never"
	objOutFile.WriteLine strUser & ";Never"
    Else
        Wscript.Echo strUser & ";" & objList.Item(strUser)
	objOutFile.WriteLine strUser & ";" & objList.Item(strUser)
    End If
Next

' Clean up.
adoConnection.Close
