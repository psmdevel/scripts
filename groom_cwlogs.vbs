On Error Resume Next
Set oFS=CreateObject("Scripting.FileSystemObject")
Set objFolder=oFS.GetFolder("n:\sites")
For Each objSubFolder in objFolder.SubFolders
	strTargetFolder="n:\sites\" & objSubFolder.Name & "\Program Files\eClinicalWorks"
	If oFS.FolderExists(strTargetFolder) Then
		Set objTargetFolder=oFS.GetFolder(strTargetFolder)
		For Each objFile In objTargetFolder.Files
			strFileName=objFile.Name
			If Len(strFileName) >= 7 Then
				If Left(strFileName,2)="cw" And Right(strFileName,4)=".log" Then
					vDateLastAccessed=objFile.DateLastAccessed
					vDateDiff=DateDiff("d",vDateLastAccessed,Now())
					If vDateDiff > 3 Then
						Err.Clear
						strFilePath=objFile.Path
						oFS.DeleteFile strFilePath
						If Err.Number > 0 Then
							Wscript.Echo "Failed: " & strFilePath & " (" & Err.Description & ")"
						Else
							Wscript.Echo "Deleted: " & strFilePath
	
						End If
					End if
				End If
			End if
		Next
	End If
Next