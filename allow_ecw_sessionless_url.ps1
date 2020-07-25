#--Add specified URL to ecw_sessionless_url table for one or all sites

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '--url' -or $L -eq '-u') {$URL = $R}
        <#NYI
        if ($L -eq '--list'){$LIST = $R}#>
        if ($L -eq '--delete'){$DELETE = $TRUE}
        if ($L -eq '--help' -or $L -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--url|-u' = "Specify the URL to insert. ex. '/mobiledoc/jsp/catalog/xml/GetServerTimeStamp.jsp' "
'--delete' = "remove specified URL from ecw_sessionless_url table"
                }|Format-List; exit
            }

#Open-MySqlConnection -Server dbclust11 -Port 5000 -Credential (get-Auth.ps1) -Database control_data -ConnectionName control
if ($SID)
    {
        $SITES = (Invoke-MySQL -Site 000 -Query "select siteid from sitetab where siteid = $SID and status = 'active' order by siteid;").siteid
    }
    else
        {
            $SITES = (Invoke-MySQL -Site 000 -Query "select siteid from sitetab where siteid > 001 and status = 'active' order by siteid;").siteid
            $COUNT = $SITES.count
            
        }
#Close-SqlConnection -ConnectionName control

<#--NYI
if ($LIST)
    {
        $URLS = Get-Content $LIST
    }#>


if (!$SID)
    {
[PSCustomObject] @{
'Sites selected' = "$COUNT"
'URL' = "$URL"

} | Format-list

        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}

    }

foreach ($SITE in $SITES)
    {
        $SID = $SITE
        $SHOW = Show-Site --site=$SID --tool
        $DBCLUST = $SHOW.db_cluster
        $Auth_SID = $SHOW.auth_sid
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SITE.dbuser_pwd
        #foreach ($)
        #Write-Host "DEBUG: insert ignore into ecw_sessionless_url (ecw_url) values ('$URL');";exit
        Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Credential $Auth_SID -ConnectionName "SQL$SID" -Database mobiledoc_$SID
        write-host -NoNewline "Site$SID`: $URL`:"
        if ($DELETE)
            {
                
                $TEST_Query1 = (Invoke-SqlQuery -ConnectionName "SQL$SID" -Query "select ecw_url from ecw_sessionless_url;").ecw_url
                $TEST1 = $TEST_Query1|where {$_.ecw_url -eq "$URL"}
                if ($TEST1)
                    {
                        Invoke-SqlUpdate -ConnectionName "SQL$SID" -Query "delete from ecw_sessionless_url where ecw_url = '$URL' limit 1;"|Out-Null
                    }
                #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="delete from ecw_sessionless_url where ecw_url = '$URL' limit 1;"
                $TEST_Query2 = (Invoke-SqlQuery -ConnectionName "SQL$SID" -Query "select ecw_url from ecw_sessionless_url;").ecw_url
                $TEST2 = $TEST_Query2|where {$_.ecw_url -eq "$URL"}
                if (!$TEST2)
                    {
                        Write-Host -ForegroundColor Green "[REMOVED]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
                else
                    {
                        Invoke-SqlUpdate -ConnectionName "SQL$SID" -Query "insert ignore into ecw_sessionless_url (ecw_url) values ('$URL');"
                        #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into ecw_sessionless_url (ecw_url) values ('$URL');"
                        #invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp');"
                        $TEST3 = Invoke-SqlQuery -ConnectionName "SQL$SID" -Query "select ecw_url from ecw_sessionless_url where ecw_url ='$URL';"
                        #$TEST2 = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecw_url from ecw_sessionless_url where ecw_url ='/mobiledoc/jsp/catalog/xml/GetFTPConfiguration.jsp';"
                        if ($TEST3)
                            {
                                Write-Host -ForegroundColor Green "[OK]"
                            }
                                else
                                    {
                                        Write-Host -ForegroundColor Red "[FAIL]"
                                    }
                    }
        Close-SqlConnection -ConnectionName "SQL$SID"

    }