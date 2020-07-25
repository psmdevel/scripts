On Error Resume Next
Set objFS=CreateObject("Scripting.FileSystemObject")
Set objFolder=objFS.GetFolder("c:\alley")
For Each objSubFolder in objFolder.SubFolders

	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\logs",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\logs\interfacelogs",".log",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\logs\archivedlogs",".zip",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\logs\weblogs",".zip",2
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\logs\portal",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\logs",".log",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\logs",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\logs\archivedlogs",".zip",3
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6",".zip",3
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\temp",".pdf",3
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat6\webapps",".zip",3
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempHubPics",".jpg",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\training",".zip",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\jsp\orderSet\educationPDFs",".pdf",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\jsp\catalog\xml\migration",".txt",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\jsp\edi\PQRI",".pdf",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempHubPics",".jpeg",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempHubPics",".gif",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempMedSummaryPics",".jpg",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempOrderSetsImport",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempOrderSetsExport",".txt",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempOSDistro",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempPtStmnts",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempPtStmnts",".txt",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\tempSyndromic",".txt",5
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\logs",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\logs\interfacelogs",".log",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\logs\archivedlogs",".zip",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\logs\weblogs",".zip",2
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\logs\portal",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\logs",".log",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\logs",".txt",1
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\logs\archivedlogs",".zip",3
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7",".zip",3
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7",".mdmp",3
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\temp",".pdf",3
	GroomFolder "c:\alley\" & objSubFolder.Name & "\tomcat7\webapps",".zip",3
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempHubPics",".jpg",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\training",".zip",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\jsp\orderSet\educationPDFs",".pdf",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\jsp\catalog\xml\migration",".txt",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\jsp\edi\PQRI",".pdf",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempHubPics",".jpeg",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempHubPics",".gif",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempMedSummaryPics",".jpg",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempOrderSetsImport",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempOrderSetsExport",".txt",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempOSDistro",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempPtStmnts",".xml",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempPtStmnts",".txt",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\tempSyndromic",".txt",5
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat7\webapps\mobiledoc\jsp\catalog\xml\migration\importcpt\data",".txt",1
	GroomFolder "C:\alley\" & objSubFolder.Name & "\tomcat6\webapps\mobiledoc\jsp\catalog\xml\migration\importcpt\data",".txt",1
	GroomFolder "c:\labif\" & objSubFolder.Name & "\HL7\MeyersAMD\vb",".txt",5
	GroomFolder "c:\labif\" & objSubFolder.Name & "\HL7\MeyersAMD\vb",".log",5
	GroomFolder "C:\Documents and Settings\All Users\Application Data\FTPGetter\LOG",".bak",1

	'--delete certain folders
	Dim strTomcatVersions(1)
	Dim strFolderArray(1)
	strFolderArray(0)="webapps\mobiledoc\WebHelp"
	strFolderArray(1)="webapps\mobiledoc\jsp\webemr"
	strTomcatVersions(0)="tomcat6"
	strTomcatVersions(1)="tomcat7"
	For nFolderIndex=0 To uBound(strFolderArray)
		For nTomcatVersionIndex=0 to uBound(strTomcatVersions)
			strFolderPath="C:\alley\" & objSubFolder.Name & "\" & strTomcatVersions(nTomcatVersionIndex) & "\" & strFolderArray(nFolderIndex)
			If objFS.FolderExists(strFolderPath) Then
				Err.Clear
				objFS.DeleteFolder strFolderPath,True
				If Err.Number=0 Then
					Wscript.Echo "deleted folder: " & strFolderPath
				Else
					Wscript.Echo "error deleting folder: " & strFolderPath
					Wscript.Echo "error: " & Err.Description
				End If
			End if
		Next
	Next

	'--and get rid of the huge ftp voyager log
	objFS.DeleteFile "C:\Program Files\RhinoSoft\FTP Voyager Beta\Logs"

Next

Sub GroomFolder(strTargetFolder,strFileExt,intDateDiff)
	If objFS.FolderExists(strTargetFolder) Then
		Set objTargetFolder=objFS.GetFolder(strTargetFolder)
		For Each objFile In objTargetFolder.Files
			nFileSize=objFile.Size
			If "." & lCase(objFS.GetExtensionName(objFile.Name))=lCase(strFileExt) Then
				vDayDiff=DateDiff("d",objFile.DateLastModified,Now())
				If vDayDiff > intDateDiff Or nFileSize > 100000000 Then
					Err.Clear
					strFilePath=objFile.Path
					objFS.DeleteFile strFilePath
					If Err.Number > 0 Then
						Wscript.Echo "failed: " & strFilePath & " (" & Err.Description & ")"
					Else
						Wscript.Echo "deleted: " & strFilePath
					End If
				End If
			End If
		Next
	End If
End Sub
