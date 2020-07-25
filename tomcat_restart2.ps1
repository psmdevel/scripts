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
if ($STATUS -and $RESTART){Write-Host "--status is a standalone option.";exit}
if ($STATUS -and $START){Write-Host "--status is a standalone option.";exit}
if ($STATUS -and $STOP){Write-Host "--status is a standalone option.";exit}
If (!$LABHOST) 
        {
         $SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
         $LABHOST = $SHOW.interface_server
        }
if ($RESTART -and !$STOP -and !$START) {$STOP = 'True';$START = 'True'}

#--Get the tomcat service version and path
$SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
$TOMCATVER = $SERVICE.pathname.split('\')[3]
$SIDPID = $SERVICE.processid
$WORK = "\\$LABHOST\c$\alley\site$SID\$TOMCATVER\work\catalina"
$TESTWORK = Test-Path $WORK

#--Stop the tomcat service and clear the work directory
if ($STOP)
    {
        Write-Host "Stopping site$SID $TOMCATVER on $LABHOST"
        Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Service $using:SERVICE.name}
        Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Process -id $using:SIDPID -Force -ErrorAction SilentlyContinue}
        Write-Host "Clearing work directory"
        if ($TESTWORK -eq $TRUE){Remove-Item -Force -Recurse $WORK}

    }

#--Start the tomcat service and run CheckDB
if ($START)
    {
        Invoke-Command -ComputerName $LABHOST -ScriptBlock {Start-Service $using:SERVICE.name}
        CheckDB -s="$SID"
    }

#--CheckDB
if ($STATUS)
    {CheckDB -s="$SID"}