On Error Resume Next
Set oFS=CreateObject("Scripting.FileSystemObject")
strFolderPath="R:\IECache\"

'--if this is sunday, try deleting full folder paths
intWeekDay=WeekDay(Now)
If intWeekDay=vbSunday Then
	Set objFolder=oFS.GetFolder(strFolderPath)
	For Each objSubFolder In objFolder.Subfolders
		strSubFolderPath=objSubFolder.Path
		If lCase(Left(strSubFolderPath,15))="r:\iecache\site" Then
			Err.Clear
			oFS.DeleteFolder strSubFolderPath
			If Err.Number > 0 Then
				Wscript.Echo "Failed to delete folder: " & strSubFolderPath & " (" & Err.Description & ")"
			Else
				Wscript.Echo "Deleted folder: " & strSubFolderPath 
			End If
		End If
	Next
	Wscript.Quit
End If

'--on all other days, recursively walk the filesystem and delete individual files
GroomFolder strFolderPath

Sub GroomFolder(strFolderPath)
	On Error Resume Next
	'--Wscript.Echo "Processing folder: " & strFolderPath
	Set objFolder=oFS.GetFolder(strFolderPath)

	'--groom the files in this folder
	For Each objFile in objFolder.Files
		strFilePath=objFile.Path
		vDateLastAccessed=objFile.DateLastAccessed
		vFileDays=DatePart("y",vDateLastAccessed)
		vDayDiff=DatePart("y",Now())-vFileDays
		If vDayDiff > 1 Then
			Err.Clear
			oFS.DeleteFile strFilePath
			If Err.Number > 0 Then
				Wscript.Echo "Failed: " & strFilePath & " (" & Err.Description & ")"
			Else
				Wscript.Echo "Deleted: " & strFilePath
			End If
		Else	
			'--Wscript.Echo "Skipped: " & strFilePath		
		End If
	Next

	'--process this folder's subfolders
	For Each objSubFolder in objFolder.SubFolders
		GroomFolder objSubFolder.Path
	Next	

End Sub