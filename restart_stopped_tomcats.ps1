#--Get the list of stopped tomcats
$DATE1 = Get-Date -Format yyyy-MM-dd-hh:mm:ss
Write-Output "$DATE1 Checking for stopped tomcats..."|Out-File c:\scripts\logs\restart_stopped_tomcats.log -Append
$STOPPED = Get-Service -displayname 'apache tomcat*','if_site126_pm_amd'| Where-Object {$_.status -eq "Stopped" -and $_.StartType -eq 'automatic'}

#--Restart each stopped tomcat, with a pause between each one
foreach ($SID in $STOPPED)
    {
        $NAME = $SID.name
        $DATE = Get-Date -Format yyyy-MM-dd-hh:mm:ss
        Write-Output "$DATE Tomcat $NAME found stopped. Attempting to start service."|Out-File c:\scripts\logs\restart_stopped_tomcats.log -Append
        Start-Service $SID
        timeout 15|Out-Null
    }