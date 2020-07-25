#--Check log_analyze on linux tomcat servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '-a') {$A = 'True'}
        if ($L -eq '-b') {$B = 'True'}
        if ($L -eq '--both') {$BOTH = $TRUE}
        if ($L -eq '-v') {$VERBOSE = '-v'}
        if ($L -eq '--list') {$LIST = '--list'}
        if ($L -eq '--log') {$LOG = $R}
        if ($L -eq '--latency') {$LATENCY = $R}
        if ($L -eq '--csv') {$CSV = '--csv'}
    }

#--Help. Call help file from linux script
if ($HELP -or !$SID)
    {plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 "/scripts/log_analyze";exit}


#--Test and confirm variables
#If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--If no tomcats specified, assume both should be checked
If (!$BOTH -and !$A -and !$B){$BOTH = 'True'}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

#--Determine the tomcats to CTM
$APPARRAY = @()
if ($BOTH) {$APPARRAY += $APP1, $APP2}
    else
        {if ($A -eq 'True') {$APPARRAY += $APP1}
         if ($B -eq 'True') {$APPARRAY += $APP2}
        }

#--Log_analyze on the specified tomcats
if ($LOG) {$LOG = "--log=$LOG"}
if ($LATENCY) {$LATENCY = "--latency=$LATENCY"}          
foreach ($APP in $APPARRAY)
    {
        Write-Output "~: Checking Site$SID tomcat calls on $APP"
        #Write-Host "DEBUG script string: /scripts/log_analyze --site=$SID $VERBOSE $LIST $LOG $LATENCY $CSV"
        Connect-Ssh  -ComputerName $APP -ScriptBlock "/scripts/log_analyze --site=$SID $VERBOSE $LIST $LOG $LATENCY $CSV"|Select-String -NotMatch 'requests processed'
    }
        