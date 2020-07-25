#--Reapply insertupdate.xml via eCW_APU2 tool 

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
            if ($L -eq '-e' -or $L -eq '--ecw') {$ECWAPU2 = $TRUE}
            #if ($L -eq '-w' -or $L -eq '--webxml') {$WEBXML = $TRUE}
            #if ($L -eq '--script') {$USESCRIPT = $TRUE}
            if ($L -eq '--reverse') {$REVERSE = '-Descending'}
            if ($L -eq '-n' -or $L -eq '--nolog') {$NOLOG = $TRUE}
            #if ($L -eq '--to' -or $L -eq '-t') {$T_FOLD = $R}
            #if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Reapplies specific pieces of the $PATCH patch'
'--help|-h' = "Display available options"
'--site|-s' = "Specify site number"
'--patch|-p' = "Specify patch number"
'--ecw|-e' = "Reapply SQL queries using eCW_APU2 tool"
'--script' = "Reapply SQL queries using patch_minor"
'--webxml|-w' = "Apply web.xml to tomcat7/conf/ from patch"
'--nolog|-n' = "Ignore rerun logging"
                }|Format-List; exit
            }
$site_array = @()
if ($m_SID)
    {
        $site_array += $m_SID
    }
        else
            {
                foreach ($s in (query_mass_deploy.ps1 --patch=$PATCH --nosummary).siteid|Sort-Object $REVERSE)
                    {
                        $site_array += $s
                    }
            }
 
 
[xml]$sqlversions = Get-Content M:\scripts\PatchCentral\patches\patch_$PATCH\Tool\runtime\sql\_insertupdate.xml
$versions = (($sqlversions).queries.query|where {$_.dbvendor -ne 'mssql'}).version
foreach ($SID in $site_array)
    {
        
        if (-not(Get-Content M:\scripts\PatchCentral\temp\mass_deployment\$PATCH\rerun.txt|Select-String "site$SID completed","site$SID started") -or $NOLOG)
            {
                if ($PWD -ne 'm:\scripts\patchcentral')
                    {
                        cd 'm:\scripts\patchcentral'
                    }
            
                $SHOW = Show-Site --site=$SID --tool
                #$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
                #--Get the DB info
                $DBCLUST = $SHOW.db_cluster
                $DBUSER = "site$SID`_DbUser"
                $DBPWD = $SHOW.dbuser_pwd
                #--Get the tomcat info
                #$APPCID = $SHOW.app_cluster_id[0]
                #$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
                $APP1 = $SHOW.a1
                $APP2 = $SHOW.a2
                
                if ((Invoke-MySQL -site $SID  -query "show variables like 'net_read_timeout';").value -lt 3600)
                    {
                        Invoke-MySQL -site $SID -update -query "set global net_read_timeout = 3600;"
                    }
                if ((Invoke-MySQL -site $SID -query "show variables like 'net_write_timeout';").value -lt 900)
                    {
                        Invoke-MySQL -site $SID -update -query "set global net_write_timeout = 900;"
                    }
                if (!$NOLOG)
                    {
                        Write-Output "site$SID started"|Out-File M:\scripts\PatchCentral\temp\mass_deployment\$PATCH\rerun.txt -Append
                    }
                if ($USESCRIPT)
                    {
                        m:\scripts\patchcentral\patch_minor.cmd --patch:$PATCH -f -y -r --skipcopywebapps --site:$SID
                    }
                if ($ECWAPU2)
                    {
                        foreach  ($version in $versions)
                            {
                                Invoke-MySQL -site $SID -update -query "delete from upgrade_sqlversions where version = '$version' limit 1;"
                            }
                        & "M:\scripts\PatchCentral\utils\eCW_APU2\$SID\eCW_APU2.exe"|Wait-Process
                    }
                if ($WEBXML)
                    {
                        $WEBXMLSIZE = (Get-ChildItem -File M:\scripts\PatchCentral\patches\patch_$PATCH\server\conf\web.xml).length
                        if ((Get-ChildItem -File \\$APP2\site$SID\tomcat7\conf\web.xml).Length -ne $WEBXMLSIZE)
                            {
                                Write-Host -NoNewline "Site$SID`: Copying web.xml to conf:"
                                cpi M:\scripts\PatchCentral\patches\patch_$PATCH\Server\conf\web.xml \\$APP1\site$SID\tomcat7\conf\
                                cpi M:\scripts\PatchCentral\patches\patch_$PATCH\Server\conf\web.xml \\$APP2\site$SID\tomcat7\conf\
                                if ((Get-ChildItem -File \\$APP1\site$SID\tomcat7\conf\web.xml).Length -eq $WEBXMLSIZE -and (Get-ChildItem -File \\$APP2\site$SID\tomcat7\conf\web.xml).Length -eq $WEBXMLSIZE)
                                    {
                                        Write-Host -ForegroundColor Green '[OK]'
                                    }
                                        else
                                            {
                                                Write-Host -ForegroundColor Red '[FAIL]'
                                            }
                                Write-Host -NoNewline "Setting web.xml permissions..."
                                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP1 "chown site$SID`:mycharts\\site$SID`_group /alley/site$SID/tomcat7/conf/web.xml"
                                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP1 "chmod 660 /alley/site$SID/tomcat7/conf/web.xml"
                                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP2 "chown site$SID`:mycharts\\site$SID`_group /alley/site$SID/tomcat7/conf/web.xml"
                                plink -i M:\scripts\sources\ts01_privkey.ppk root@$APP2 "chmod 660 /alley/site$SID/tomcat7/conf/web.xml"
                                Write-Host " Done."
                                #setperms --site=$SID --both
                            }
                    }
                if (!$NOLOG)
                    {
                        Write-Output "site$SID completed"|Out-File M:\scripts\PatchCentral\temp\mass_deployment\$PATCH\rerun.txt -Append
                    }
                allow_getservertimestamp.ps1 --site=$SID
            }
        
        
    }