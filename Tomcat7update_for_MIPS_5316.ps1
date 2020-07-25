#--Tomcat7 update for MIPS

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

$SITES = find_enabled_patch.ps1 --patch=5316 --status=complete

foreach ($SID in $SITES.site)
    {
        #$SID = $SITE.site
        $SHOW = invoke-mysql --site=000 --query="select * from sitetab where siteid = $SID;"
        $APPCID = $SHOW.app_cluster_id[0]
        $APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        $APP1 = $APPID.a1
        $APP2 = $APPID.a2
        $DBCLUST = $SHOW.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SHOW.dbuser_pwd
        Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update userprofile set serverxmlhttpobject = 0;"
        $CHECKXMLOBJECT = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from userprofile where serverxmlhttpobject = 1;"
        $XMLOBJ = $CHECKXMLOBJECT.'count(*)'
        if ($XMLOBJ -eq 0)
            {Write-Host -NoNewline "Site$SID`:";Write-Host -ForegroundColor Green "[$XMLOBJ]"}
                else
                    {Write-Host -NoNewline "Site$SID`:";Write-Host -ForegroundColor Red "[$XMLOBJ]"}
        <#
        $APP1_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP1 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
        $APP2_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP2 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
        if ($APP1_TC_VERSION -eq 6)
            {
                plink -i \scripts\sources\ts01_privkey.ppk root@$APP1 "/scripts/convert_tomcat --site=$SID -v=7 -y"
            }
        if ($APP2_TC_VERSION -eq 6)
            {
                plink -i \scripts\sources\ts01_privkey.ppk root@$APP2 "/scripts/convert_tomcat --site=$SID -v=7 -y"
            }#>
    }