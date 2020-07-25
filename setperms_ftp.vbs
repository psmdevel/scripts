'--purpose: sets site-specific permissions on the ftp server folders for a site

Option Explicit
On Error Resume Next
Dim STATUS, oShell, oExec, sLine, TimeToBailOut, objArgs, i, SID, sSID, oNet, UserName, BtnCode, vMsg, IpAddress
Dim bKey


Wscript.Echo "Disabled"
Wscript.Sleep 5000
Wscript.Quit


Const STATUS_LOGGED_IN=1
Const STATUS_CMD_SENT=2
Const STATUS_CMD_ACK=3
Const STATUS_CMD_COMPLETE=4

Set objArgs = WScript.Arguments
If objArgs.Count > 0 Then
	UserName = objArgs(0)
Else
	Set oNet = WScript.CreateObject("WScript.Network")
	UserName = oNet.UserName
End if

If UCase(Left(UserName,4))="SITE" Then
	SID=Mid(UserName,5,3)
Else
	Wscript.Echo "  --error: '" & UCase(Left(UserName,4)) & "' is not a valid site ID."
	Wscript.Quit
End if

'--make sure SID is numeric
Err.Clear
i=SID+1
If Err.Description <> vbNullString Then
	Wscript.Echo "  --error: site ID is not numeric."
	Wscript.Quit
End If

'--make sure it is a natural number less than 1000
SID=CInt(SID)
If SID < 1 Or SID > 999 Then
	Wscript.Echo "  --error: site ID is out of range."
	Wscript.Quit
End if

'--pad it as necessary
If Len(SID)=1 Then SID="00" & SID
If Len(SID)=2 Then SID="0" & SID

'--add ssh host key to registry if necessary
Set oShell=CreateObject("Wscript.Shell")
Err.Clear
bKey = oShell.RegRead("HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:192.168.10.202")
If Err.Description <> vbNullString Then
	oShell.RegWrite "HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:192.168.10.202", "0x23,0xe6395f980b5e0950de6470b1027d9f19a18b81ae944c160ed97fcfd69da1e2a2c10b0486b38d54f63792ac8ee1ffe62115ce57f251471b8d0c3cac2acf5eacff293e5a0c0ba612c79792f015af44241da5ff05bfb9c4e755a4320c2824f0ef2571202e0c0473546f081fc51a9ef1f57841583ecf1ad3e722a084736681f362e9e3ca51b90f0b0e2ff77ba6950b3dc279e38e1fcfb2c4428a34345cfa0b8aaf3614701d326822a01c340bbfa501030371192c6f6743bdba562f67d92e97b26c548a9ae290c2d1399141052027fcb40379f6abacc5b2b90ca91407bfef2a7eaaf72e94089c1ad263170ac91800c72918288f6eac5f3b5d4b79182d9faf58e580cb", "REG_SZ"
	Err.Clear
	bKey = oShell.RegRead("HKCU\Software\SimonTatham\PuTTY\SshHostKeys\rsa2@22:192.168.10.202")
	If Err.Description <> vbNullString Then
		'--error adding registry key so abort
		Wscript.Quit
	End If
End If
Set oShell=Nothing

Wscript.Echo
Wscript.Echo "Setting ftp folder permissions for site" & SID & ":"
Wscript.Echo
SetPerms ("192.168.10.202")
Wscript.Echo
Wscript.Echo "Done."
Wscript.StdIn.ReadLine
Wscript.Quit

Sub SetPerms(IpAddress)

	Set oShell=CreateObject("Wscript.Shell")
	Set oExec=oShell.Exec("plink -i m:\scripts\sources\ts01_privkey.ppk root@" & IpAddress)

	TimeToBailOut=False

	Do While Not TimeToBailOut

		'--get a line of output
		sLine = oExec.StdOut.ReadLine
		'Wscript.Echo sLine

		'--login detected?
		If Instr(sLine,"Last login") Then
			oExec.StdIn.WriteLine vbCr
			STATUS=STATUS_LOGGED_IN
		End If
		
		'--command ack?
		If Instr(sLine,"--setting ftp") Then
			oExec.StdIn.WriteLine vbCr
			STATUS=STATUS_CMD_ACK
			Wscript.Echo "Server (" & IpAddress & ") " & sLine
		End If
		
		'--shell prompt detected?
		If Instr(sLine, "root@") Then
			Select Case STATUS

				Case STATUS_LOGGED_IN
					STATUS=STATUS_CMD_SENT
					oExec.StdIn.WriteLine "setperms site" & SID & vbCr

				Case STATUS_CMD_ACK
					oExec.StdIn.WriteLine Chr(7) & "exit" & vbCr
					TimeToBailOut=True
					
			End Select
		End If
	Loop
End Sub
