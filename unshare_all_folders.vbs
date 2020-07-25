strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
	& "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
Set colShares = objWMIService.ExecQuery("Select * from Win32_Share")
For Each objShare in colShares
	strShareName=lCase(objShare.Name)
	If Left(strShareName,4)="site" and Len(strShareName)=7 Then
		Wscript.Echo "deleting " & strShareName
		objShare.Delete
	End if
Next
