#--Allow getServerTimeStamp.jsp & GetFTPConfiguration.jsp via ecw_sessionless_url

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
Import-Module SimplySql

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($L -eq '--help' -or $L -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number. If no site specified, applies changes to all active sites."
                }|Format-List; exit
            }

#--Get the list of sites
$Auth = get-Auth.ps1
Open-MySqlConnection -Server dbclust11 -Port 5000 -Credential $Auth -Database control_data
if ($m_SID)
    {
        $SITES = Invoke-SqlQuery -Query "select * from sitetab where siteid = $m_SID and status = 'active' order by siteid;"
        #$SITES = invoke-mysql --site=000 --query="select * from sitetab where siteid = $m_SID and status = 'active' order by siteid;"
    }
    else
    {
        $SITES = Invoke-SqlQuery -Query "select * from sitetab where siteid > 001 and status = 'active' order by siteid;"
        #$SITES = invoke-mysql --site=000 --query="select * from sitetab where siteid > 001 and status = 'active' order by siteid;"
    }
Close-SqlConnection

#--loop through the list of sites and allow the JSP's
foreach ($SITE in $SITES)
    {
        $SID = $SITE.siteid
        $SHOW = Show-Site --site=$SID --tool
        $DBCLUST = $SHOW.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SHOW.dbuser_pwd
        $Auth_SID = $SHOW.auth_sid
        write-host -NoNewline "Site$SID`:"
        Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Credential $Auth_SID -Database mobiledoc_$SID
        #$TEST_TABLE = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="show tables like 'ecw_sessionless_url';"
        $TEST_TABLE = Invoke-SqlQuery -query "show tables like 'ecw_sessionless_url';"
        if ($TEST_TABLE)
            {
                $TEST1 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp';"
                $TEST2 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp';"
                $TEST3 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp';"
                #$TEST1 = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp';"
                #$TEST2 = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp';"
                #$TEST5 = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp';"
                if (!$TEST1 -or !$TEST2 -or !$TEST3)
                    {
                        Write-Host -NoNewline "updating..."
                    }

                Invoke-SqlUpdate -query "insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp');"|Out-Null
                Invoke-SqlUpdate -query "insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp');"|Out-Null
                Invoke-SqlUpdate -query "insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp');"|Out-Null
                #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp');"
                #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp');"
                #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp');"
                $TEST4 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp';"
                $TEST5 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp';"
                $TEST6 = Invoke-SqlQuery -query "select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp';"
        
        
                if ($TEST4 -and $TEST5 -and $TEST6)
                    {
                
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                        
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
                else
                    {
                        Write-Host -ForegroundColor Gray "[SKIPPING]"
                    }
        Close-SqlConnection
    }