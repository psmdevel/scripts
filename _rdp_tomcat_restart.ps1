#--Restarts the specified lab interface tomcat, on both local and remote hosts

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\Invoke_MySQL_RO.psm1
$SID = (($env:USERNAME).split('e')[-1]).split('_')[0]

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        #if ($L -eq '--site' -or $L -eq '-s' ){$SID = "$R"}
        if ($L -eq '--host'){$LABHOST = $R}
        if ($ARG -eq '--restart'){$RESTART = 'True'}
        if ($ARG -eq '--start'){$START = 'True'}
        if ($ARG -eq '--stop'){$STOP = 'True'}
        if ($ARG -eq '--status'){$STATUS = 'True'}
        if ($ARG -eq '--clear'){$CLEAR = 'True'}
        }

#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        'Description' = "Manages Interface Tomcat Service for site$SID"
        '--status' = 'Show Interface Service Status'
        '--stop' = 'Stop Interface Service'
        '--start' = 'Start Interface Service'
        '--restart' = 'Restart Interface Service'
        '--clear' = 'Clear Interface Service work folder'
        } | Format-list;exit
    }

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

$SHOW = Invoke_MySQL_RO -s=000 --query="select * from sitetab where siteid = $SID;"
$LABHOST = $SHOW.interface_server
if ($LABHOST -notlike 'lab*'){Write-Host "Interface server was specified, but no dedicated interface server was found.";exit}
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
    Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Service -Force $using:SERVICE.name -NoWait}
    Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Process -id $using:SIDPID -Force -ErrorAction SilentlyContinue}
    if ($CLEAR)
        {
            
            if ($TESTWORK -eq $TRUE)
                {
                    Write-Host "Clearing work directory"
                    Remove-Item -Force -Recurse $WORK
                }
                    else
                        {
                            Write-Host "Could not clear work directory"
                        }
        }
    }

#--Start the tomcat service and run CheckDB
if ($START)
{
    Invoke-Command -ComputerName $LABHOST -ScriptBlock {Start-Service $using:SERVICE.name}
    CheckDB --site=$SID --timeout
}

#--CheckDB
if ($STATUS)
{
    CheckDB --site=$SID --timeout
}
            