Import-Module M:\scripts\invoke-mysql.psm1 -Force

$SHOW = invoke-mysql --site=000 --query="select * from sitetab where status like 'a%' and siteid < 780 and siteid > 001 order by siteid;"
    
foreach ($SITE in $SHOW)    
    {
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        if (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from serverdetails where portno = '8080';")
            {
                Write-Host -NoNewline "Site$SID`: "
                invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="delete from serverdetails where portno = '8080';" 
                if (-not (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from serverdetails where portno = '8080';"))
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
    }