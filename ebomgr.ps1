#--Run ebomgr script on cognos server for specified site

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($ARG -eq '--status') {$STATUS = '--status'}
        if ($ARG -eq '--start') {$START = '--start'}
        if ($ARG -eq '--stop') {$STOP = '--stop'}
        if ($ARG -eq '--restart') {$RESTART = '--restart'}
        if ($ARG -eq '--help') {$HELP = $TRUE}
    }

#--Test and confirm variables
If (!$SID) {$HELP = $TRUE}
if (!$STATUS -and !$START -and !$RESTART -and !$STOP)
    {
        $HELP = $TRUE
    }

#--Display available options
if ($HELP -or !$ARGS)
{
    [PSCustomObject] @{
      'Description' = 'Manage or query the eBO service for a specified site ID'

      '--site|-s' = 'Specify site ID'
      '--status' = 'Show eBO service status'
      '--start' = 'Start eBO service for specified site'
      '--stop' = 'Stop eBO service for specified site'
      '--help|-h' = 'Display available options'
    #'--count' = 'get the number of completed sites'
    } | Format-list;exit
}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the eBO info
$COGNOS = $SHOW.ebo_server
if (!$COGNOS)
    {
        Write-Host "eBO Server does not exist for site$SID";exit
    }


#--Run ebomgr on cognos server
Write-Host "~: ebomgr on $COGNOS"
Connect-Ssh -computername $COGNOS -scriptblock "/scripts/ebomgr --site=$SID $STATUS $START $RESTART $STOP $HELP"
#plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$COGNOS /scripts/ebomgr --site=$SID $STATUS $START $RESTART $STOP $HELP