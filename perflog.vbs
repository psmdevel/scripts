Set oFS=CreateObject("Scripting.FileSystemObject")
Set oLOG=oFS.OpenTextFile("m:\scripts\logs\perflog-" & Year(Now()) & "-" & Month(Now()) & "-" & Day(Now()) & ".out",2,True)
Set objCimv2 = GetObject("winmgmts:root\cimv2")
Set objRefresher = CreateObject("WbemScripting.SWbemRefresher")

' Add items to the SWbemRefresher
' Without the SWbemRefreshableItem.ObjectSet call,
' the script will fail
Set objMemory = objRefresher.AddEnum _
    (objCimv2, _ 
    "Win32_PerfFormattedData_PerfOS_Memory").ObjectSet
Set objDiskQueue = objRefresher.AddEnum _
    (objCimv2, _
    "Win32_PerfFormattedData_PerfDisk_LogicalDisk").ObjectSet
Set objQueueLength = objRefresher.AddEnum _
    (objCimv2, _
    "Win32_PerfFormattedData_PerfNet_ServerWorkQueues").ObjectSet

' Initial refresh needed to get baseline values
objRefresher.Refresh
intSkips=0
intLongest=0
intGrThan5=0
intTotalSecs=0
intLoops=0
Do While True
	LastTimer=CurrTimer
	CurrTimer=Timer
	intElapsed=Round(CurrTimer-LastTimer)
	'burn the first three loops to avoid spurious data
	If intLoops > 3 Then
		If intElapsed > 1 Then
			intSkips=intSkips+1
			intTotalSecs=intTotalSecs+intElapsed
			If intElapsed > 5 Then
				intGrThan5=intGrThan5+1
			End If
			If intElapsed > intLongest Then
				intLongest=intElapsed
			End If
			oLog.Write Time & " Skip: " & intElapsed & ", Total Skips: " & intSkips & ", Total Secs: " & intTotalSecs & ", Longest: " & intLongest & ", Greater Than 5: " & intGrThan5 & ", Queues:"
			For Each intDiskQueue in objDiskQueue
        			oLog.Write " " & intDiskQueue.CurrentDiskQueueLength & " " & intDiskQueue.AvgDiskQueueLength
				Exit For
    			Next
    			oLog.Write vbCrLf
		End If
	Else
		intLoops=intLoops+1
	End if
    	Wscript.Sleep 1000
    	objRefresher.Refresh
Loop