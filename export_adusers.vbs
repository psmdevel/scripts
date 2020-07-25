' ExportADUsers.vbs
' Sample VBScript to Find and Export AD users into CSV file .
' Author: http://www.morgantechspace.com/
' ------------------------------------------------------'
 
Option Explicit
 
' Initialize required variables.
Dim adoCommand, adoConnection
Dim varBaseDN, varFilter, varAttributes
Dim objRootDSE, varDNSDomain, strQuery, adoRecordset
Dim objFSO, objCSVFile
 
' Setup ADO objects.
Set adoCommand = CreateObject("ADODB.Command")
Set adoConnection = CreateObject("ADODB.Connection")
adoConnection.Provider = "ADsDSOObject"
adoConnection.Open "Active Directory Provider"
Set adoCommand.ActiveConnection = adoConnection
 
' Search entire Active Directory domain.
Set objRootDSE = GetObject("LDAP://RootDSE")
 
varDNSDomain = objRootDSE.Get("defaultNamingContext")
varBaseDN = "<LDAP://" & varDNSDomain & ">"
 
' varBaseDN is Domain DN, you can give your own OU DN instead of 
' getting from "defaultNamingContext"
' like varBaseDN = "<LDAP://OU=TestOU,DC=Domain,DC=com>"
 
' Filter for user objects.
varFilter = "(&(objectCategory=person)(objectClass=user))"
 
' Comma delimited list of attribute values to retrieve.
varAttributes = "name,samaccountname,distinguishedname,whencreated,mail"
 
' Construct the LDAP syntax query.
strQuery = varBaseDN & ";" & varFilter & ";" & varAttributes & ";subtree"
adoCommand.CommandText = strQuery
adoCommand.Properties("Page Size") = 1000
adoCommand.Properties("Timeout") = 20
adoCommand.Properties("Cache Results") = False
 
' Run the query.
Set adoRecordset = adoCommand.Execute
 
' Create CSV file 
Const ForWriting = 2
 
Set objFSO = CreateObject("Scripting.FileSystemObject")
 
' Here, I have given CSV file path as "ADUsers.csv", this will create ADUsers.csv file
' where you placed and execute this VB Script file. You can give your own file path
' like "C:\Users\Administrator\Desktop\ADUsers.csv"
 
Set objCSVFile = objFSO.CreateTextFile("ADUsers.csv", _ 
    ForWriting, True)
 
' Write selected AD Attributes as CSV columns(first line)
 objCSVFile.Write varAttributes 
 
 objCSVFile.Writeline ' New Line
 
' Enumerate the resulting recordset.
Do Until adoRecordset.EOF
 
   ' Retrieve values and write into CSV file.
 
     objCSVFile.Write adoRecordset.Fields("name").Value & ","
     objCSVFile.Write adoRecordset.Fields("samaccountname").Value & ","
     objCSVFile.Write adoRecordset.Fields("distinguishedname").Value & ","
     objCSVFile.Write adoRecordset.Fields("whencreated").Value & ","
     objCSVFile.Write adoRecordset.Fields("mail").Value & ""
     objCSVFile.Writeline  ' New Line
 
    ' Move to the next record in the recordset.
    adoRecordset.MoveNext
Loop
 
 objCSVFile.Close
 
' close ado connections.
adoRecordset.Close
adoConnection.Close
 
' Active Directory User properites are exported Successfully as CSV File