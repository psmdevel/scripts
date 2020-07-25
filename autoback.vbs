' -- File: 	autoback.vbs
'    Version: 	1.24
'    Author: 	Eric Robinson
'    Date: 	10/17/07
'    Purpose:	Backs up the local server and notifies backup operators.
'
' Disclaimer: No express or implied warranties are made with respect to this script's functionality or fitness 
' for a particular purpose.

option explicit

' -- config section. replace values after the "=" signs as needed. 
'	ADMIN values will receive notification emails.
'	SERVICE values will be stopped before backup and restarted afterwards. 
'	RUNAS is name of user that will execute the scheduled task. 
'	SLEEPTIME is number of seconds to sleep after tape subsystem refresh before backup.
'	TESTMODE=True will backup a single small file to keep runtime short.
'	MEDIATYPE=TAPE or FILE. If TAPE then set TAPEDRIVE. If FILE, then set DESTPATH.
'	If MEDIATYPE=FILE and KEEPOLDBACKUP=True, previous day's .bkf file will be renamed to .old.
'	Set SMTP settings as required

const SERVER="DC01"
const MEDIATYPE="FILE"
const MEDIANAME="4mm DDS"
const DESTPATH="\\ts04\ntbackups"
const TAPEDRIVE=""
const ADMIN1="admin@psmnv.com"
const ADMIN2=""
const ADMIN3=""
const ADMIN4=""
const SERVICE1=""
const SERVICE2=""
const SERVICE3=""
const SERVICE4=""
const SERVICE5=""
const SERVICE6=""
const RUNAS="root"
const SLEEPTIME=90
const EJECT_TAPE=False
const TESTMODE=False
const KEEPOLDBACKUP=True
const SMTPSERVER="popmail"
const SMTPAUTH=False
const SMTPUSER="test"
const SMTPPASS="test"

' -- usage notes:
' 	create directory c:\scripts and place this script in it
'	create subdirectory c:\scripts\logs
'	copy blat.exe (available on the Internet) to %windir%\system32
'	create file c:\scripts\autoexec.bks containing paths to be backed up. use notepad to save file as unicode!
'	edit the config section above
'	test from a command line
'	set up a scheduled task

' -- file system objects
dim oFS, oFile, oFolder, oFiles, oBackupLog, oOutFile, oLog

' -- shell and execution objects
dim oWSH, oExec

' -- reading and parsing vars
dim sLine, iPos, bError

' -- logging vars
dim sDateStamp, sStartDate, sEndDate, sStartTime, sEndTime, sDuration, sFullBackStart, sFullBackEnd, sLog, sTapeDate

' --counting and numeric vars
dim iFilesSkipped, iFiles, iDirectories, iBytes, iBackup, iTotalBytes, iTotalFiles

' --array of skipped files
dim SkippedFiles() 

' -- general vars
dim bExchFlag, aBackups(50,10), x, sResource, iDay, sDay, sComputer, sCmd, sTapeLabel

' -- initialize vars
sLog="c:\scripts\logs\autoback.log"

' -- Create file system object
Set oFS = CreateObject("Scripting.FileSystemObject")

' -- Create the shell object
Set oWSH = CreateObject("WScript.Shell")

' -- delete the old log file
if oFS.FileExists("c:\scripts\logs\autoback.log") Then
	oFS.DeleteFile("c:\scripts\logs\autoback.log")
end if

' -- Open the log file for append, create if necessary
Set oLog=oFS.OpenTextFile(sLog,8,True)
oLog.WriteLine Now() & ": script started."

' -- Stop services
if SERVICE1 <> vbNullString Then StopService(SERVICE1)
if SERVICE2 <> vbNullString Then StopService(SERVICE2)
if SERVICE3 <> vbNullString Then StopService(SERVICE3)
if SERVICE4 <> vbNullString Then StopService(SERVICE4)
if SERVICE5 <> vbNullString Then StopService(SERVICE5)
if SERVICE6 <> vbNullString Then StopService(SERVICE6)

' -- Get the computer name
Set oExec=oWSH.Exec("hostname")
Do While Not oExec.StdOut.AtEndOfStream
	sLine=oExec.StdOut.ReadLine
	if sLine <> vbNullString Then
		sComputer=sLine
		Exit Do
	end if
Loop

' -- Log the files to be backed up
Set oFile=oFS.OpenTextFile("c:\scripts\sources\autoback.bks",1,False,True)
oLog.WriteLine Now() & ": files to be backed up:"
Do While Not oFile.AtEndOfStream
	oLog.WriteLine Now() & ": " & vbTab & vbTab & oFile.ReadLine
Loop
Set oFile=Nothing

' -- refresh the tape subsystem
If MEDIATYPE="TAPE" Then
	sCmd="rsm refresh /lf""" & TAPEDRIVE & """"
	oLog.WriteLine Now() & ": running command: rsm refresh /lf""" & TAPEDRIVE & """"
	Set oExec=oWSH.Exec(sCmd)
	Do While Not oExec.StdOut.AtEndOfStream
		sLine=oExec.StdOut.ReadLine
		if sLine <> vbNullString Then
			oLog.WriteLine Now() & ": " & sLine
		end if
	Loop
	oLog.WriteLine Now() & ": sleeping " & SLEEPTIME & " seconds..."
	Wscript.Sleep SLEEPTIME * 1000
	oLog.WriteLine Now() & ": waking up... (yawn, stretch)..."
End If

' -- Run ntbackup
If MEDIATYPE="TAPE" Then
	sTapeLabel=MakeTapeLabel()
	if TESTMODE=False then
		sCmd="ntbackup backup @c:\scripts\sources\autoback.bks /m normal /j """ & sTapeLabel & """ /p """ & MEDIANAME & """ /n """ & sTapeLabel & """ /d """ & sTapeLabel & """ /v:no /r:no /l:s /rs:no /hc:on /um"
		oLog.WriteLine Now() & ": running command: " & sCmd
		set oExec=oWSH.Exec(sCmd)
		Do While oExec.Status=0
			Wscript.Sleep 100
		Loop
	else
		oLog.WriteLine Now() & ": test mode enabled, autoback.bks will be ignored."
		sCmd="ntbackup backup c:\boot.ini /m normal /j """ & sTapeLabel & """ /p """ & MEDIANAME & """ /n """ & sTapeLabel & """ /d """ & sTapeLabel & """ /v:no /r:no /l:s /rs:no /hc:on /um"
		oLog.WriteLine Now() & ": running command: " & sCmd
		set oExec=oWSH.Exec(sCmd)
		Do While oExec.Status=0
			Wscript.Sleep 100
		Loop
	end if
Else
	'it's a file backup; first shuffle the old backup files
	if oFS.FileExists(DESTPATH & "\" & SERVER & ".bkf") Then
		oLog.WriteLine Now() & ": backup file " & SERVER & ".bkf exists on destination"
		if oFS.FileExists(DESTPATH & "\" & SERVER & ".old") Then
			oLog.WriteLine Now() & ": old backup file " & SERVER & ".old also exists on destination; deleting it..."
			oFS.DeleteFile DESTPATH & "\" & SERVER & ".old"
		End If
		If KEEPOLDBACKUP=True Then
			oFS.MoveFile DESTPATH & "\" & SERVER & ".bkf", DESTPATH & "\" & SERVER & ".old" 
			oLog.WriteLine Now() & ": " & SERVER & ".bkf renamed to " & SERVER & ".old"
		Else
			oLog.WriteLine Now() & ": will overwrite previous backup file"
		End If
	Else
		oLog.WriteLine Now() & ": " & SERVER & ".bkf does not exist on destination"
	End If
	'now run the file backup
	sCmd="ntbackup.exe backup @C:\scripts\sources\autoback.bks /n """ & SERVER & """ /d ""scripted-backup"" /v:no /r:no /rs:no /hc:off /m normal /j ""autoback"" /l:s /f """ & DESTPATH & "\" & SERVER & ".bkf"""
	oLog.WriteLine Now() & ": running command: " & sCmd
	set oExec=oWSH.Exec(sCmd)
	Do While oExec.Status=0
		Wscript.Sleep 100
	Loop
End If
oLog.WriteLine Now() & ": ntbackup exited."

' -- eject tape if necessary
if MEDIATYPE="TAPE" and EJECT_TAPE=True Then
	oLog.WriteLine Now() & ": running command: rsm eject /lf""" & TAPEDRIVE & """"
	sCmd="rsm eject /lf""" & TAPEDRIVE & """"
	Set oExec=oWSH.Exec(sCmd)
	Do While Not oExec.StdOut.AtEndOfStream
		sLine=oExec.StdOut.ReadLine
	if sLine <> vbNullString Then
		oLog.WriteLine Now() & ": " & sLine
	end if
	Loop
end if

' -- Start services
if SERVICE1 <> vbNullString Then StartService(SERVICE1)
if SERVICE2 <> vbNullString Then StartService(SERVICE2)
if SERVICE3 <> vbNullString Then StartService(SERVICE3)
if SERVICE4 <> vbNullString Then StartService(SERVICE4)
if SERVICE5 <> vbNullString Then StartService(SERVICE5)
if SERVICE6 <> vbNullString Then StartService(SERVICE6)

oLog.WriteLine Now() & ": parsing ntbackup log."
' -- Find the most recent ntbackup log file and open it
Set oFolder = oFS.GetFolder("C:\Documents and Settings\" & RUNAS & "\Local Settings\Application Data\Microsoft\Windows NT\NTBackup\data")
Set oFiles = oFolder.Files
For Each oFile in oFiles
	If oFile.DateLastModified > sDateStamp Then
		sDateStamp = oFile.DateLastModified
		Set oBackupLog = oFile
	End If				
Next
Set oFile = oFS.OpenTextFile(oBackupLog.Path,1,False,True)

Redim SkippedFiles(0)
iBackup=0
iFilesSkipped=0
bExchFlag=False

' -- Start parsing the log
Do While not oFile.AtEndOfStream
	sLine=oFile.ReadLine
	
	If Instr(sLine,"Backup of") > 0 Or Instr(sLine,"hadow copy") > 0 Then
		iBackup=iBackup+1
		iPos=instr(sLine,"""")
		sLine=Right(sLine,Len(sLine)-iPos)
		sLine=Left(sLine,Len(sLine)-1)
		sResource=sLine
		aBackups(iBackup,1)=sResource
	end if
	
	If Instr(sLine, "Backup started on") Then
		iPos=Instr(sLine, "on")
		sLine=Right(sLine,Len(sLine)-(iPos+2))
		iPos=Instr(sLine," ")
		sStartDate=Trim(Left(sLine,iPos))
		iPos=Instr(sLine,"at")
		sStartTime=Trim(Right(sLine,Len(sLine)-(iPos+2)))
		aBackups(iBackup,2)=sStartDate 
		aBackups(iBackup,3)=sStartTime
		If iBackup=1 Then
			sFullBackStart=sStartDate & "  " & sStartTime
		End If
	End If
	
	If Instr(sLine, "Backup completed on") Then
		iPos=Instr(sLine, "on")
		sLine=Right(sLine,Len(sLine)-(iPos+2))
		iPos=Instr(sLine," ")
		sEndDate=Trim(Left(sLine,iPos))
		iPos=Instr(sLine,"at")
		sEndTime=Trim(Right(sLine,Len(sLine)-(iPos+2)))
		aBackups(iBackup,4)=sEndDate
		aBackups(iBackup,5)=sEndTime
	End If
	
	If Left(sLine,6) = "Files:" Then
		iPos = Instr(sLine," ")
		iFiles = Trim(Right(sLine, Len(sLine) - iPos))
		aBackups(iBackup,6)=iFiles
	End If	

	If Left(sLine,12) = "Directories:" Then
		iPos = Instr(sLine," ")
		iDirectories = Trim(Right(sLine, Len(sLine) - iPos))
		aBackups(iBackup,7)=iDirectories
	End If	

	If Left(sLine,6) = "Bytes:" Then
		iPos = Instr(sLine," ")
		iBytes = Trim(Right(sLine, Len(sLine) - iPos))
		aBackups(iBackup,8)=iBytes
	End If	

	If Left(sLine,5) = "Time:" Then
		iPos = Instr(sLine," ")
		sDuration = Trim(Right(sLine, Len(sLine) - iPos))
		aBackups(iBackup,9)=sDuration
	End If	

	If Instr(sLine,"in use - skipped") Then
		iPos=Instr(sLine, "\")
		sLine=Right(sLine,Len(sLine)-iPos)
		iPos=Instr(sLine," in use - skipped") 
		sLine=Trim(Left(sLine,iPos))
		x=Ubound(SkippedFiles)+1
		Redim Preserve SkippedFiles(x)
		SkippedFiles(x)= sResource & "\" & sLine
		iFilesSkipped=iFilesSkipped+1
	Else
		If Instr(Ucase(sLine),"PROBLEM") or Instr(Ucase(sLine),"DID NOT") or Instr(Ucase(sLine),"COULD NOT") or Instr(Ucase(sLine),"WARN") or Instr(Ucase(sLine),"ERROR") or Instr(Ucase(sLine),"FAIL") Then
			bError=True
		End If
	End If
Loop

' --Set the end date.
sFullBackEnd = sEndDate & "  " & sEndTime

' --Delete the old output file if necessary.
If oFS.FileExists("c:\scripts\logs\autoback_report.txt") Then
	oFS.DeleteFile("c:\scripts\logs\autoback_report.txt")
End If

' --Start a new output file
Set oOutFile = oFS.CreateTextFile("c:\scripts\logs\autoback_report.txt")

oOutFile.WriteLine("Backup summary from " & SERVER & ".")
oOutFile.WriteLine("  Start:" & vbTab & sFullBackStart)
oOutFile.WriteLine("  Finish:" & vbTab & sFullBackEnd)
oOutFile.WriteLine("")
iTotalFiles=0
iTotalBytes=0
For x = 1 to iBackup
	oOutFile.WriteLine("Backup of " & aBackups(x,1))
	oOutFile.WriteLine("  -- started:" & vbTab & aBackups(x,2) & " at " & aBackups(x,3))
	oOutFile.WriteLine("  -- finished:" & vbTab & aBackups(x,4) & " at " & aBackups(x,5))
	If aBackups(x,10)=True Then
		oOutFile.WriteLine("  -- processed " & aBackups(x,8) & " bytes in " & aBackups(x,9)) & vbCrlF
	Else
		oOutFile.WriteLine("  -- processed " & aBackups(x,8) & " bytes (" & aBackups(x,6) & " files in " _
			& aBackups(x,7) & " directories) in " & aBackups(x,9)) & vbCrLf
		iTotalFiles=iTotalFiles + aBackups(x,6)
	End If
	iTotalBytes=iTotalBytes + aBackups(x,8)
Next
oOutFile.WriteLine("")
oOutFile.WriteLine("Total files:" & vbTab & iTotalFiles)
oOutFile.WriteLine("Total bytes:" & vbTab & Round(iTotalBytes/1000000,2) & "MB")
oOutFile.WriteLine("")
oOutFile.WriteLine(iFilesSkipped & " files were skipped across all data sets.")
iFilesSkipped=Ubound(SkippedFiles)
If iFilesSkipped > 0 Then
	For x = 1 to iFilesSkipped
		oOutFile.WriteLine("  " & SkippedFiles(x))
	Next
End If

oOutFile.WriteLine("")
If bError Then
	oOutFile.WriteLine("*** WARNING! At least one error was encountered. The backup may have failed. Check the NTBackup Logs!!")
	oOutFile.WriteLine("")
End If
oOutFile.WriteLine("Script finished.")

Set oOutFile=Nothing
Set oFile=Nothing

oLog.WriteLine Now() & ": mailing report to backup operators."

if ADMIN1 <> vbNullString Then NotifyAdmin(ADMIN1)
if ADMIN2 <> vbNullString Then NotifyAdmin(ADMIN2)
if ADMIN3 <> vbNullString Then NotifyAdmin(ADMIN3)

oLog.WriteLine Now() & ": done."

Private Sub StopService(TheService)
	dim oWSH2,oExec2,sError
	sCmd="net stop """ & TheService & """"
	oLog.WriteLine Now() & ": running command: " & sCmd
	Set oWSH2=CreateObject("Wscript.Shell")
	Err.Clear
	Set oExec2=oWSH2.Exec(sCmd)
	sError=Err.Description
	if sError<>vbNullString Then oLog.WriteLine Now() & ": error: " & sError
	Do While Not oExec2.StdOut.AtEndOfStream
		sLine=Trim(oExec2.StdOut.ReadLine)
		if sLine <> vbNullString Then oLog.WriteLine Now() & ": " & sLine
	Loop
	Set oWSH2=Nothing
	Set oExec2=Nothing
End Sub

Private Sub StartService(TheService)
	dim oWSH2,oExec2,sError
	sCmd="net start """ & TheService & """"
	oLog.WriteLine Now() & ": running command: " & sCmd
	Set oWSH2=CreateObject("Wscript.Shell")
	Err.Clear
	Set oExec2=oWSH2.Exec(sCmd)
	sError=Err.Description
	if sError<>vbNullString Then oLog.WriteLine Now() & ": error: " & sError
	Do While Not oExec2.StdOut.AtEndOfStream
		sLine=Trim(oExec2.StdOut.ReadLine)
		if sLine <> vbNullString Then oLog.WriteLine Now() & ": " & sLine
	Loop
	Set oWSH2=Nothing
	Set oExec2=Nothing
End Sub

Private Function MakeTapeLabel()
	dim sNow, sLabel, sChar, i
	sNow=Now()
	for i=1 to len(sNow)
		sChar=mid(sNow,i,1)
		if instr("/: ",sChar) then
			sChar="-"
		end if
		sLabel=sLabel & sChar
	next
	MakeTapeLabel="daily-" & sLabel
End Function

Private Sub NotifyAdmin(TheAdmin)
	dim oWSH2, oExec2, sCmd2
	Set oWSH2 = CreateObject("Wscript.Shell")
	If SMTPAUTH=True Then
		sCmd2="blat c:\scripts\logs\autoback_report.txt -server " & SMTPSERVER & " -u " & SMTPUSER & " -pwd " & SMTPPASS & " -t " & TheAdmin & " -f autoback@" & SERVER & " -s """ & SERVER & " Backup Complete"""
	Else
		sCmd2="blat c:\scripts\logs\autoback_report.txt -server " & SMTPSERVER & " -t " & TheAdmin & " -f autoback@" & SERVER & " -s """ & SERVER & " Backup Complete"""
	End If
	oLog.WriteLine Now() & ": running command: " & sCmd2
	Set oExec2=oWSH2.Exec(sCmd2)
	Set oExec2=Nothing
	Set oWSH2=Nothing
End Sub

' -- End

