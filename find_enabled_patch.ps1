#--Find sites with the specified patch enabled, either in 'download' or 'complete' status

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

foreach ($ARG in $ARGS)
    {
        if ($ARG -like '*:*' -and $ARG -notlike '*:\*'){Write-Output 'Please use "=" to specify arguments'; exit}
        $L,$R = $ARG -split '=',2
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        if ($L -eq '--status' -or $L -eq '-s' ){$STATUS = $R}
        if ($L -eq '--version' -or $L -eq '-v' ){$VERSION = $TRUE}
        if ($L -eq '--cluster' -or $L -eq '-c' ){$CLUSTER = $R}
        if ($L -eq '--reseller' -or $L -eq '-r'){$RESELLER = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = '-h'}
    }

if (!$PATCH -and !$STATUS -and !$HELP) {$HELP = '-h'}
#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Display sites enabled for the specified patch"
'--help|-h' = "Display available options"
'--patch|-p' = "Specify the patch number"
'--version|-v' = "Display the current client version"
'--cluster' = "Check patch status for sites on a given cluster. ex.: dbclust09, app10, lab03, cognos02, ts13"
'--status' = "Specify the patch status. download,complete,install. Defaults to (any)"
                }|Format-List; exit
            }

<#if ($HELP)
    {
     plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch -h;exit
    }   

if (!$STATUS)
    {
        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch --patch=$PATCH
    }
        else
            {plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch --patch=$PATCH --status=$STATUS}

#>
#--Get the list of active sites

    if ($CLUSTER -or $RESELLER)
        {
            if ($CLUSTER -like 'virtdb*' -or $CLUSTER -like 'dbclust*')
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and db_cluster = '$CLUSTER' and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
            if ($CLUSTER -like 'app*')
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and app_cluster_id = (select id from app_clusters where a1 = '$CLUSTER' or a2 = '$CLUSTER') and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
            if ($CLUSTER -like 'ts*' -or $CLUSTER -like 'rdp*')
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and ts_cluster_id = (select id from ts_clusters where rdp_address like '$CLUSTER%' or t1 = '$CLUSTER' or t2 = '$CLUSTER') and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
            if ($CLUSTER -like 'lab*')
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and interface_server = '$CLUSTER' and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
            if ($CLUSTER -like 'cognos*' -or $CLUSTER -like 'vmhost*')
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and ebo_server = '$CLUSTER' and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
            if ($RESELLER)
                {
                    $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and reseller_id = '$RESELLER' and siteid > 001 and siteid < 999 and siteid not in (119,780) order by siteid;"
                }
        }
        else
            {
                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where siteid > 001 and siteid < 999 and siteid not in (119,780) and status = 'active' order by siteid;"
            }
$SITELIST = @()
foreach ($SITE in $SITEARRAY)
    {
        
        $SID = $SITE.siteid
        $SHOW = Show-Site --site=$SID -p --tool
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SITE.dbuser_pwd
        $PATCHESLIST = New-Object System.Object
        $APU_ID = $SITE.apu_id
        $SITE_VERSION = $SHOW.clientversion
        $TIMEZONE = $SHOW.time_zone
        #write-host "DEBUG: site$SID"

        if (!$STATUS)
            {
                $SQUERY = $SHOW.patches|where {$_.ecwpatchid -eq $PATCH}
                #$SQUERY = Invoke-MySQL -site $SID -query "select ecwpatchid,patchdescription,status from patcheslist where ecwpatchid='$PATCH'"
                
                <#if ($VERSION)
                    {
                        $SITE_VERSION = $SHOW.clientversion
                    }#>
            }
                else
                    {
                        $SQUERY = $SHOW.patches|where {$_.ecwpatchid -eq $PATCH -and $_.status -like "$STATUS*"}
                        #$SQUERY = Invoke-MySQL -site $SID -query "select ecwpatchid,patchdescription,status from patcheslist where ecwpatchid='$PATCH' and status like '$STATUS%';"
                        
                        <#if ($VERSION)
                            {
                                $SITE_VERSION = Invoke-MySQL -site $SID -query "select value from itemkeys where name = 'clientversion';"
                            }#>
                    }
        if ($SQUERY)
            {
                $ECWPATCHID = $SQUERY.ecwpatchid
                $PATCHDESC = $SQUERY.patchdescription
                $PSTATUS = $SQUERY.status
                $PATCHESLIST | Add-Member -Type NoteProperty -Name Site -Value "$SID"
                $PATCHESLIST | Add-Member -Type NoteProperty -Name PatchID -Value "$ECWPATCHID"
                $PATCHESLIST | Add-Member -Type NoteProperty -Name Description -Value "$PATCHDESC"
                $PATCHESLIST | Add-Member -Type NoteProperty -Name Status -Value "$PSTATUS"
                $PATCHESLIST | Add-Member -Type NoteProperty -Name APU_ID -Value "$APU_ID"
                if ($VERSION)
                    {
                        #$SITE_VERSION = $SITE_VERSION.value
                        $PATCHESLIST | Add-Member -Type NoteProperty -Name ClientVersion -Value "$SITE_VERSION"
                    }
                $PATCHESLIST | Add-Member -Type NoteProperty -Name Time_Zone -Value $TIMEZONE
                $SITELIST += $PATCHESLIST
                $PATCHESLIST
            }
    }

if (!$STATUS){$STATUS = 'any'}
#$SITELIST
$TOTAL = $SITELIST.count
Write-host "
Total sites with patch $PATCH in status ($STATUS): $TOTAL"

            

