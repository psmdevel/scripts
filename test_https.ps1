#--Test HTTPS & UseHttpInstdofFtpVb

#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
    }

$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

if ($SHOW.status -eq 'inactive'){echo "Site is inactive, exiting.";exit}

#--Get the terminal server info
$TSCID = $SHOW.ts_cluster_id[0]
$TSID = Invoke-MySQL -s=000 --query="select * from ts_clusters where id = $TSCID;"
$TS = $TSID.t1
$TSR1 = Invoke-MySQL -s=000 --query="select * from ts_properties where name = '$TS';"
$TS_ROOT = $TSR1.site_root.split(':')[0]