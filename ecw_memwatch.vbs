'--purpose: watches usage of the eclinicalworks.exe process for site103

Set objShell=CreateObject("Wscript.Shell")
Set objFS=CreateObject("Scripting.FileSystemObject")
Set objLogFile=objFS.OpenTextFile("m:\scripts\logs\ecw_memory.log",8,True)
Do While True
	objLogFile.WriteLine Now() & ": --------------------------------------------------------------------------"
	Set objExec=objShell.Exec("tasklist /v")
	Do While Not objExec.StdOut.AtEndOfStream
		strLine=objExec.StdOut.ReadLIne
		If Instr(lCase(strLine),"eclinicalworks.exe") > 0 And Instr(lCase(strLine),"site103") > 0 Then
			objLogFile.WriteLine strLine
		End If
	Loop
	Wscript.Sleep 60000
Loop


