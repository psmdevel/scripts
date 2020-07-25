#--get RDP site folder sizes

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($ARG -eq '--help' -or $ARG -eq '-h' ){$HELP = $TRUE}
            if ($L -eq '--cluster' ){$CLUSTER = $R}
            #if ($L -eq '--proceed' -or $L -eq '-y' ){$PROCEED = $TRUE}
    }

#--Help
if ($HELP -or !$ARGS) {
[PSCustomObject] @{
'Description' = 'Gets RDP folder sizes for the specified cluster or site'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--cluster' = 'Specify the RDP cluster, rdp|ts'
                }|Format-List; exit
            }

#--Get the target cluster information
if ($CLUSTER -like 'rdp*')
    {
        $CLUSTER_ID = (Invoke-MySQL -Site 000 -Query "select id from ts_clusters where rdp_address like '$CLUSTER%';").id
        if ($CLUSTER_ID.count -gt 1)
            {
                Write-Output "Multiple clusters found, please narrow search";exit
            }
    }
if ($CLUSTER -like 'ts*')
    {
        $CLUSTER_ID = (Invoke-MySQL -Site 000 -Query "select id from ts_clusters where t1 = '$CLUSTER' or t2 = '$CLUSTER';").id
    }
if ($CLUSTER -eq [int])
    {
        $CLUSTER_ID = $CLUSTER
    }
if ($m_SID)
    {
        $CLUSTER_ID = (Invoke-MySQL -Site 000 -Query "select ts_cluster_id from sitetab where status like 'a%' and siteid = $m_SID;").ts_cluster_id
    }
$TS1 = (Invoke-MySQL -Site 000 -Query "select t1 from ts_clusters where id = $CLUSTER_ID;").t1
$TS2 = (Invoke-MySQL -Site 000 -Query "select t2 from ts_clusters where id = $CLUSTER_ID;").t2
$SITE_ROOT = (Invoke-MySQL -Site 000 -Query "select site_root from ts_properties where name = '$TS1';").site_root
$SITE_ROOT_UNC = $SITE_ROOT.split(':')[0] + '$'
$TS_ARRAY = @()
$TS_ARRAY += $TS1
$TS_ARRAY += $TS2
$TOTAL = @()
#--RDP Site size
$SITEARRAY = @()
if ($m_SID)
    {
        $SITEARRAY += $m_SID
    }
        else
            {
                foreach ($s in Invoke-MySQL -Site 000 -Query "select * from sitetab where status like 'a%' and ts_cluster_id = $CLUSTER_ID order by siteid;")
                    {
                        $SITEARRAY += $s.siteid
                    }
            }
foreach ($SID in $SITEARRAY)
    {
        #$SID = $s.siteid
        Write-Host -NoNewline "Site$SID`: "
        #--get disk usage
        $size = (gci \\$TS1\$SITE_ROOT_UNC\sites\$SID -Recurse|measure length -sum).sum/1GB
        $size = [math]::round($size,2)
        Write-Host "$size`GB"
        $TOTAL += $size
    }
$SUM = 0
$TOTAL|foreach {$SUM +=$_}
Write-Host "Total: $SUM"