#--Run ebomgr script on cognos server for specified site

#--Import the Invoke_MySQL_RO.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\Invoke_MySQL_RO.psm1
$SID = (($env:USERNAME).split('e')[-1]).split('_')[0]

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        #if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($ARG -eq '--status') {$STATUS = '--status'}
        if ($ARG -eq '--start') {$START = '--start'}
        if ($ARG -eq '--stop') {$STOP = '--stop'}
        if ($ARG -eq '--restart') {$RESTART = '--restart'}
        if ($ARG -eq '--help') {$HELP = $TRUE}
    }

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
if (!$STATUS -and !$START -and !$RESTART -and !$STOP)
    {
        $HELP = $TRUE
    }

#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        'Description' = "Manages eBO Service for site$SID"
        '--status' = 'Show eBO Service Status'
        '--stop' = 'Stop eBO Service'
        '--start' = 'Start eBO Service'
        '--restart' = 'Restart eBO Service'
        } | Format-list;exit
    }
#--Get the site information from ControlData
$SHOW = Invoke_MySQL_RO -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the eBO info
$COGNOS = $SHOW.ebo_server
if (!$COGNOS)
    {
        Write-Host "eBO Server does not exist for site$SID";exit
    }


#--Run ebomgr on cognos server
Write-Host "~: ebomgr on $COGNOS"
plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$COGNOS /scripts/ebomgr --site=$SID $STATUS $START $RESTART $STOP