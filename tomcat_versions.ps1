#--Find mismatched or outdated tomcats

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Get the list of active sites

$SHOW = invoke-mysql --site=000 --query="select * from sitetab where siteid > 001 and status like 'a%';"
$SITELIST = @()
Foreach ($SITE in $SHOW)
    {
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        #--Get the tomcat info
        $APPCID = $SITE.app_cluster_id[0]
        $APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        $APP1 = $APPID.a1
        $APP2 = $APPID.a2
        $APP1_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP1 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
        $APP2_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP2 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
        $SITE_VERSION = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'clientversion';"
        $SITE_VERSION = $SITE_VERSION.value
        $APPTOMCATS = New-Object System.Object

        #if ($APP1_TC_VERSION -ne $APP2_TC_VERSION -or $APP1_TC_VERSION -eq '6' -or $APP2_TC_VERSION -eq '6')
            #{
                $APPTOMCATS | Add-Member -Type NoteProperty -Name Site -Value "$SID"
                $APPTOMCATS | Add-Member -Type NoteProperty -Name Tomcat_A -Value "$APP1_TC_VERSION"
                $APPTOMCATS | Add-Member -Type NoteProperty -Name Tomcat_B -Value "$APP2_TC_VERSION"
                $APPTOMCATS | Add-Member -Type NoteProperty -Name ClientVersion -Value "$SITE_VERSION"
                $SITELIST += $APPTOMCATS
                $APPTOMCATS
            #}
    }