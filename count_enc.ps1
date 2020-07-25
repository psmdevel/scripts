#--count_enc, but for powershell!

#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--date' -or $L -eq '-d'){$CUSTOM_DATE = $R}
        if ($L -eq '--cluster' -or $L -eq '-c'){$CLUSTER = $R}
        if ($ARG -eq '--remaining'){$REMAINING = $TRUE}
        if ($ARG -eq '--nosummary'){$NOSUMMARY = $TRUE}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Displays encounter counts, defaulting to all sites (today)"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number"
'--date|-d' = "Specify a date. Format: yyyyMMdd"
'--cluster' = "Specify sites on a given cluster. ex.: dbclust09, app10, lab04, cognos02, ts13"
'--remaining' = "Only counts encounters after the current time."
                }|Format-List; exit
            }
#--Establish which date to query for encounter counts
if (!$CUSTOM_DATE)
    {
        $THE_DATE = get-date -Format yyyyMMdd
    }
        else
            {
                $THE_DATE = $CUSTOM_DATE
            }

#Write-Host "DEBUG: $THE_DATE"
#Write-Host "DEBUG: $CLUSTER"
if ($m_SID)
    {
        #$SHOW = Show-Site --site=$SID --tool
        $m_SHOW = Invoke-MySQL -site 000 -query "select siteid,keywords,db_cluster,dbuser_pwd from sitetab where siteid = '$m_SID' and status = 'active';"
        $SITEARRAY = @()
        $SITEARRAY += $m_SHOW
    }
        else
            {
                if ($CLUSTER)
                    {
                        if ($CLUSTER -like 'virtdb*' -or $CLUSTER -like 'dbclust*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and db_cluster = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'app*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and app_cluster_id = (select id from app_clusters where a1 = '$CLUSTER' or a2 = '$CLUSTER') and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'ts*' -or $CLUSTER -like 'rdp*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and ts_cluster_id = (select id from ts_clusters where rdp_address like '$CLUSTER%' or t1 = '$CLUSTER' or t2 = '$CLUSTER') and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'lab*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and interface_server = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'cognos*' -or $CLUSTER -like 'vmhost*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and ebo_server = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                    }
                        else
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
            }
$ENC_COUNT = @()
$REMAIN_COUNT = @()
#Write-Host "DEBUG: $SITEARRAY"
foreach ($SITE in $SITEARRAY)
    {
        $SID = $SITE.siteid
        #$SHOW = Show-Site --site=$SID --tool
        $KEYWORDS = $SITE.keywords
        $DBCLUST = $SITE.db_cluster
        #$DBUSER = "site" + $SID + '_DbUser'
        #$DBPWD = $SITE.dbuser_pwd
        if (Invoke-MySQL -site $SID -query "show tables like 'enc';")
            {
                $ENCREPORT = New-Object System.Object
                #$NOW = (Invoke-MySQL -site $SID -query "select now();").'now()'
                #$HOUR = $NOW.Hour
                #$MINUTE = $NOW.Minute
                #$NOW = $NOW.split(' ')[1]
                #$TIME = "$HOUR`:$MINUTE"
        
                    
                if ($CUSTOM_DATE)
                    {
                        $SITE_REMAIN_COUNT = (Invoke-MySQL -Site $SID -Query "select count(*) from enc where date like '$THE_DATE%' and visittype <> 'LAB' and endtime > (select now());").'count(*)'
                    }
                        else
                            {
                                $SITE_REMAIN_COUNT = (Invoke-MySQL -Site $SID -Query "select count(*) from enc where date = '$THE_DATE' and visittype <> 'LAB' and endtime > (select now());").'count(*)'
                            }
                $REMAIN = 'Remaining'
                #Write-Host "DEBUG: $TIME"
                if ($CUSTOM_DATE)
                    {
                        $SITE_ENCOUNTERS = (Invoke-MySQL -Site $SID -Query "select count(*) from enc where date like '$THE_DATE%' and visittype <> 'LAB';").'count(*)'
                    }
                        else
                            {
                                $SITE_ENCOUNTERS = (Invoke-MySQL -Site $SID -Query "select count(*) from enc where date = '$THE_DATE' and visittype <> 'LAB';").'count(*)'
                            }
            
                    
                #$SITE_ENCOUNTERS = $SITE_ENC_COUNT
                #write-host "DEBUG: 'SID'$SID"
                #write-host "DEBUG: 'KEYWORDS'$KEYWORDS"
                #write-host "DEBUG: 'SITE_ENCOUNTERS'$SITE_ENCOUNTERS"
                #write-host "DEBUG: 'SITE_REMAIN_COUNT'$SITE_REMAIN_COUNT"
                $ENCREPORT | Add-Member -Type NoteProperty -Name Site -Value "$SID"
                $ENCREPORT | Add-Member -Type NoteProperty -Name Keywords -Value "$KEYWORDS"
                $ENCREPORT | Add-Member -Type NoteProperty -Name Encounters -Value "$SITE_ENCOUNTERS"
                $ENCREPORT | Add-Member -Type NoteProperty -Name Remaining -Value "$SITE_REMAIN_COUNT"
        
                $ENC_COUNT += $SITE_ENCOUNTERS
                $REMAIN_COUNT += $SITE_REMAIN_COUNT
                #Write-Output "~: $SID ($KEYWORDS): $SITE_ENCOUNTERS $REMAIN"
                $ENCREPORT
            }
    }

$SUM = 0
$SUM2 = 0
$ENC_COUNT|Foreach {$SUM +=$_}
$REMAIN_COUNT|Foreach {$SUM2 +=$_}

if (!$NOSUMMARY)
    {
        Write-Output "
        ~: Total encounters for $THE_DATE`: $SUM
        ~: Total encounters Remaining $THE_DATE`: $SUM2"
    }
