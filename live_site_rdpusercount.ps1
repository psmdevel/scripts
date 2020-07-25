#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--cluster' -or $L -eq '-c'){$CLUSTER = $R}
        #if ($L -eq '--all' -or $L -eq '-a'){$ALL = $TRUE}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Count current logged in RDP users for specified site or TS cluster"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number."
'--cluster' = "Show sites on a given TS cluster. ex.: rdp01,rdp07"
                }|Format-List; exit
            }
if ($m_SID)
    {
        $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $m_SID;"
        if ($SHOW.status -eq 'inactive')
            {
                echo "Site is inactive, exiting.";
                exit
            }
        #--Get the terminal server info
        $TSCID = $SHOW.ts_cluster_id[0]
        $TSID = Invoke-MySQL -s=000 --query="select * from ts_clusters where id = $TSCID;"
        $TS1 = $TSID.t1
        $TS2 = $TSID.t2
        #--Get practice time zone
        $TZ = $SHOW.time_zone

        #--Get the usercount from both servers

        $USERS1 = quser /server:$TS1|select-string "$m_SID`_"
        $USERS2 = quser /server:$TS2|select-string "$m_SID`_"

        $TOTALUSERS = $USERS1.count + $USERS2.count

        Write-Output "$(Get-Date -Format yyyMMdd-HH:mm:ss) - Current usercount for site$m_SID`: $TOTALUSERS"|Tee-Object $DRIVE\scripts\logs\rdpusercount_site$m_SID.txt -Append
    }

if ($CLUSTER)
    {
        #--Get the terminal server info
        #$TSCID = $SHOW.ts_cluster_id[0]
        $TSID = Invoke-MySQL -s=000 --query="select * from ts_clusters where rdp_address like '$CLUSTER%;"
        if (!$TSID)
            {
                echo "RDP Cluster '$CLUSTER' not found"
                exit
            }
        $TS1 = $TSID.t1
        $TS2 = $TSID.t2

        #--Get the usercount from both servers

        $USERS1 = quser /server:$TS1 #|select-string "$m_SID`_"
        $USERS2 = quser /server:$TS2 #|select-string "$m_SID`_"

        $TOTALUSERS = $USERS1.count + $USERS2.count

        Write-Output "$(Get-Date -Format yyyMMdd-HH:mm:ss) - Current usercount for $CLUSTER.chartwire.com: $TOTALUSERS"|Tee-Object $DRIVE\scripts\logs\rdpusercount_$CLUSTER.txt -Append
    }