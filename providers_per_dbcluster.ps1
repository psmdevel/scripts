#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$DATE = get-date -Format yyyy-MM

$DBCLUSTERS = Invoke-Mysql --site=000 --query="select cluster_name from db_clusters"

$REPORT = @()
foreach ($DB in $DBCLUSTERS.cluster_name)
    {
           $SITE = Invoke-Mysql --site=000 --query="select count(*) from sitetab where db_cluster = '$DB' and status = 'active';"
           $SITEARRAY = Invoke-Mysql --site=000 --query="select * from sitetab where db_cluster = '$DB' and status = 'active';"
           $PROV = Invoke-Mysql --site=000 --query="select count(*) from providers where siteid in (select siteid from sitetab where db_cluster = '$DB' and status = 'active') and npi is not null and npi > 0 and licensekey is not null and licensekey like 'x%' and logged_in = 'yes' order by siteid;"
           $SITECOUNT = $SITE.'count(*)'
           $PROVCOUNT = $PROV.'count(*)'
           $USERCOUNT = 0
           foreach ($SITE in $SITEARRAY)
                {
                    $SID = $SITE.siteid
                    $KEYWORDS = $SITE.keywords
                    $DBCLUST = $SITE.db_cluster
                    $DBUSER = "site" + $SID + '_DbUser'
                    $DBPWD = $SITE.dbuser_pwd
                    $SITEUIDS = Invoke-Mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select uid from users where usertype = 2 and status = 0 and delflag = 0;"
                    foreach ($UID in $SITEUIDS.uid)
                        {
                            $LOGGED_IN = Invoke-Mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from usrlogs where usrid = $UID and serverlogintime > '$DATE%';"
                            if ($LOGGED_in.'count(*)' -gt 0)
                                {
                                    $USERCOUNT++ 
                                }
                        }
                    #$SITEUSERCOUNT = $SITEUSERS.'count(*)'
                    #$USERCOUNT += $SITEUSERCOUNT
                }
            if ($PROVCOUNT -gt 0)
                {
                    $USERSPERPROVIDER = $USERCOUNT/$PROVCOUNT
                    $UPP = [math]::Round($USERSPERPROVIDER,2)
                }
            #$USERSUM = 0
            #$USERCOUNT|Foreach {$USERSUM +=$_}
            $STATISTICS = New-Object system.object
            $STATISTICS | Add-Member -Type NoteProperty -Name Cluster -Value "$DB"
            $STATISTICS | Add-Member -Type NoteProperty -Name Sites -Value "$SITECOUNT"
            $STATISTICS | Add-Member -Type NoteProperty -Name Providers -Value "$PROVCOUNT"
            $STATISTICS | Add-Member -Type NoteProperty -Name Users -Value "$USERCOUNT"
            $STATISTICS | Add-Member -Type NoteProperty -Name UsersPerProvider -Value "$UPP"
            $REPORT += $STATISTICS
            $STATISTICS#|ft *
            #echo "$DB, Sites: $SITECOUNT, Providers: $PROVCOUNT, Users: $USERCOUNT, UsersPerProvider: $UPP"
            Clear-Variable UPP
    }
$REPORT|Export-Csv $env:USERPROFILE\documents\provders_per_dbcluster_20190814.csv