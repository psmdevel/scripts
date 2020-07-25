#--Restarts the specified lab interface tomcat, on both local and remote hosts

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = "$R"}
        if ($L -eq '--host'){$LABHOST = $R}
        if ($ARG -eq '--restart'){$RESTART = 'True'}
        if ($ARG -eq '--start'){$START = 'True'}
        if ($ARG -eq '--stop'){$STOP = 'True'}
        if ($ARG -eq '--status'){$STATUS = 'True'}
        }

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
If (!$LABHOST) 
        {$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
         $LABHOST = $SHOW.interface_server
         }
<#if (Test-Path \\$LABHOST\c$\alley\site$SID\tomcat7) { $tomcatdir = 'tomcat7' }
else { $tomcatdir = 'tomcat6' }#>
$SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
$TOMCATDIR = $SERVICE.pathname.split('\')[3]
#$SERVICE = gwmi -ComputerName $LABHOST -query "select * from win32_service where name='$SID'"
$SIDPID = $SERVICE.processid

#--Stop the tomcat, local and remote hosts
Write-Host "Stopping $TOMCATDIR`_$SID on $LABHOST"

#$PROCESS = gwmi -Class win32_process -ComputerName $LABHOST -Filter "processid=$SIDPID"
Stop-Service $SERVICE.name|Out-Null
timeout 5|Out-Null
if ($SERVICE.state -ne 'stopped') {Write-host -NoNewline "Tomcat process still running, terminating..."; Stop-Process -Id $SIDPID -Force|Out-Null; Write-Host "Done"}


#-- Clear the work folder
if (!$START){
	Write-Output "Clearing \\$LABHOST\c$\alley\site$SID\$tomcatdir\work\catalina"
	Remove-Item -recurse -ErrorAction SilentlyContinue \\$LABHOST\c$\alley\site$SID\$tomcatdir\work\catalina
}
#--Start the tomcat and check DB connection
if ($STOP -ne 'True'){
    Write-host "Starting $TOMCATDIR`_$SID on $LABHOST"
	Start-Service $SERVICE.name|Out-Null
	timeout 5|Out-Null
    Write-Host "Checking Tomcat Status"
	\scripts\CheckDB.ps1 -s="$SID" --host="$LABHOST"
} else
	{Write-Host "The Tomcat for site$SID has been stopped with a Catalina clear"}
	
if ($START){
	$SERVICE.StartService()|Out-Null
	timeout 5
	\scripts\CheckDB.ps1 -s="$SID" --host="$LABHOST"
}
		
<#
$STATUS = $SERVICE2.state
write-output "Site$SID tomcat is: $STATUS"
if ($STATUS -ne 'running') 
    {Write-Output "The Tomcat for site$SID failed to start"}
else
    {Write-Host "The Tomcat for site$SID has been restarted with a Catalina clear"}
#>