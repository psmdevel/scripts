#--Update context.xml and restart tomcat

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
    }

#--Help
if ($HELP -or !$SID) {
[PSCustomObject] @{
'Description' = 'Updates the context.xml file if necessary and restarts tomcat'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
                }|Format-List; exit
            }

#--Get the site info from database
$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Get the tomcat info
$APPCID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $APPID.a1
$APP2 = $APPID.a2

#--Check existing context.xml for presence of updated flag
if (Test-Path \\$APP1\site$SID\tomcat7\conf\context.xml)
    {
        $CONTEXTTEST1 = Get-Content \\$APP1\site$SID\tomcat7\conf\context.xml|select-string '<Context UseHttpOnly="False"'
        $CONTEXTTEST2 = Get-Content \\$APP1\site$SID\tomcat7\conf\context.xml|select-string "<Context UseHttpOnly='False'"
        if (!$CONTEXTTEST1 -and !$CONTEXTTEST2)
            {
                Write-Host -NoNewline "Site$SID`: "
                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/tomcat7/conf;sed -i 's/<Context>/<Context UseHttpOnly=\`"False\`">/g' context.xml"
                $CONTEXTTEST3 = Get-Content \\$APP1\site$SID\tomcat7\conf\context.xml|select-string '<Context UseHttpOnly="False"'
                $CONTEXTTEST4 = Get-Content \\$APP1\site$SID\tomcat7\conf\context.xml|select-string "<Context UseHttpOnly='False'"
                if ($CONTEXTTEST3 -or $CONTEXTTEST4)
                    {
                        Write-Host -ForegroundColor Green '[OK]'
                        Write-Host "Restarting site$SID tomcat A"
                        safe_tomcat.ps1 --site=$SID --a --restart --fast --force|Out-Null
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red '[FAIL]'
                            }
            }

    }
if (Test-Path \\$APP2\site$SID\tomcat7\conf\context.xml)
    {
        $CONTEXTTEST1 = Get-Content \\$APP2\site$SID\tomcat7\conf\context.xml|select-string '<Context UseHttpOnly="False"'
        $CONTEXTTEST2 = Get-Content \\$APP2\site$SID\tomcat7\conf\context.xml|select-string "<Context UseHttpOnly='False'"
        if (!$CONTEXTTEST1 -and !$CONTEXTTEST2)
            {
                Write-Host -NoNewline "Site$SID`: "
                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$SID/tomcat7/conf;sed -i 's/<Context>/<Context UseHttpOnly=\`"False\`">/g' context.xml"
                $CONTEXTTEST3 = Get-Content \\$APP2\site$SID\tomcat7\conf\context.xml|select-string '<Context UseHttpOnly="False"'
                $CONTEXTTEST4 = Get-Content \\$APP1\site$SID\tomcat7\conf\context.xml|select-string "<Context UseHttpOnly='False'"
                if ($CONTEXTTEST3 -or $CONTEXTTEST4)
                    {
                        Write-Host -ForegroundColor Green '[OK]'
                        Write-Host "Restarting site$SID tomcat B"
                        safe_tomcat.ps1 --site=$SID --b --restart --fast --force|Out-Null
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red '[FAIL]'
                            }
            }

    }