'--server_time.vbs

'--init some vars
strServerTimeFile="m:\scripts\sources\server_time.txt"
strServerTimeTmp="m:\scripts\sources\server_time.tmp"

'--create the filesystem object
Set objFS=CreateObject("Scripting.FileSystemObject")

'--enter 1-second loop
Do While True

	'--delete the old server_time.txt file if it exists
	If objFS.FileExists(strServerTimeTmp) Then
		objFS.DeleteFile strServerTimeTmp
	End if

	'--open a new temp file and write the time to it
	Set objServerTimeTmp=objFS.OpenTextFile(strServerTimeTmp,2,True)
	objServerTimeTmp.WriteLine Now()
	Set objServerTimeTmp=Nothing

	'--copy the temp file over the current time file
	objFS.CopyFile strServerTimeTmp, strServerTimeFile, True

	'--delete the temp file
	If objFS.FileExists(strServerTimeTmp) Then
		objFS.DeleteFile strServerTimeTmp
	End if

	'--sleep 1 second
	Wscript.Sleep 1000

Loop
