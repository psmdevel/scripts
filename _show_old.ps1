#--Import Invoke-MySQL module
#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '--apu') {$APU = $R}
        if ($L -eq '-p') {$PATCH = 'True'}
        if ($L -eq '-x') {$INT = 'True'}
        if ($L -eq '-l') {$LOGIN = 'True'}
        if ($L -eq '-i') {$INACTIVE = 'True'}
        if ($L -eq '--fax') {$FAX = 'True'}
        if ($L -eq '-f') {$FOOTPRINT = 'True'}
        if ($L -eq '--tool') {$TOOL = $TRUE}
        if ($L -eq '--support' -or $L -eq '--partner') {$SUPPORT_PROVIDER = $R}
        if ($L -eq '--help' -or $L -eq '-h') {$HELP = $TRUE}
    }

#--Display available options
if ($HELP)
{
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s|--site' = 'show site information for specified site ID'
    '--apu' = 'show site information for specified APU ID'
    '-p' = 'show patcheslist table'
    '-x' = 'show serverdetails table'
    '-l' = 'show latest logins'
    '-f' = 'show db & ftp footprint sizes'
    '--fax' = 'show faxserver info'
    '--support|--partner' = 'show support provider information'
    '-i' = 'show inactive site'
    } | Format-list;exit
}

if ($SUPPORT_PROVIDER)
    {
        $PROVIDER = Invoke-MySQL --site=000 --query="select * from resellers where reseller_id = '$SUPPORT_PROVIDER' and status like 'a%';"
        if (!$PROVIDER)
            {
                Write-Host "Specified Support Provider $SUPPORT_PROVIDER not found or is inactive"
                exit
            }
                else
                    {
                        $P_NAME = $PROVIDER.reseller_name
                        $P_SLOT = $PROVIDER.reseller_slot
                        $P_PWD = $PROVIDER.reseller_pwd
                        $P_TEMP = "siteXXX_s$P_SLOT"

                        [PSCustomObject] @{

                                    'Partner Name'= $P_NAME
                                    'Account Template'= $P_TEMP
                                    'Password'= $P_PWD

                                            }|Format-List;exit

                    }
    }

if ($SID) 
    {
        $SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"
        if (!$SHOW)
            {
                Write-Host "No sites found with specified Site ID";exit
            }
    }
if ($APU) 
    {
        $SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where apu_id=$APU and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"
        $SID = $SHOW.siteid
        if (!$SID)
            {
                Write-host "No sites found with specified APU ID";exit
            }    
    }
if (!$SID -and !$APU)
    {
        Write-Host "Please specify a Site or APU ID";exit
    }

#--Check if site is active
if (!$INACTIVE)
    {if ($SHOW.status -eq 'inactive')
        {Write-Host "No active sites match the query";exit}
    }

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$APP1_TOMCAT = "$APP1`:3$SID"
$APP2_TOMCAT = "$APP2`:3$SID"
$VER_URL = '/mobiledoc/jsp/catalog/xml/CheckServerVersion.jsp'
$TIME_URL = '/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp'
$DBC_URL = '/mobiledoc/jsp/catalog/xml/CheckDBConnection.jsp'

if ($SHOW.status -like 'a*')
            {
                $APP1_VERSION = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$APP1_TOMCAT$VER_URL
                $APP2_VERSION = Invoke-WebRequest -ErrorAction SilentlyContinue   -TimeoutSec 3 http://$APP2_TOMCAT$VER_URL
                $APP1_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP1 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                $APP2_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP2 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                $APP1_TIME = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$APP1_TOMCAT$TIME_URL
                $APP2_TIME = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$APP2_TOMCAT$TIME_URL
                #$APP1_CHECKDB = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$APP1_TOMCAT$DBC_URL
                #$APP2_CHECKDB = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$APP2_TOMCAT$DBC_URL
                $tomcatA = "$APP1,ver:$APP1_TC_VERSION, $APP1_TIME,patch:$APP1_VERSION"
                $tomcatB = "$APP2,ver:$APP2_TC_VERSION, $APP2_TIME,patch:$APP2_VERSION"
                $APP3 = $SHOW.interface_server
                    if ($APP3 -like 'lab*') 
                        {
                            $SERVICE = gwmi -ComputerName $APP3 win32_service|?{$_.Name -eq "$SID"} -ErrorAction SilentlyContinue|select name, displayname, startmode, state, pathname, processid
                            if ($SERVICE)
                                {
                                    $CURRENT_STATUS = $SERVICE.state
                                    $TOMCATVER = ($SERVICE.pathname.split('\')[3]).split('t')[-1]
                                    $APP3_TOMCAT = "$APP3`:3$SID"
                                    $APP3_VERSION = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 5 http://$APP3_TOMCAT$VER_URL
                                    $APP3_TIME = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 5 http://$APP3_TOMCAT$TIME_URL
                                    #$APP3_CHECKDB = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 5 http://$APP3_TOMCAT$DBC_URL
                                    
                                }
                            $tomcatC = "$APP3,ver:$TOMCATVER, $APP3_TIME,patch:$APP3_VERSION"
                        }
                    else
                       {$tomcatC = '(NULL)'}
            }
                else
                    {
                        $tomcatA = "$APP1"
                        $tomcatB = "$APP2"
                    }

#--Get the terminal server info
#$TSCID = $SHOW.ts_cluster_id[0]
#$TSID = Invoke-MySQL -s=000 --query="select * from ts_clusters where id = $TSCID;"
$TS1 = $SHOW.t1
$TS2 = $SHOW.t2
$RDP_CLUST = $SHOW.rdp_address
$RDP_CLUSTER = "$RDP_CLUST, $TS1, $TS2"

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$DBSTRING = "--site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD"

#--Get the database cluster details
#$DBDETAILS = invoke-mysql -s=000 --query="select * from db_clusters where cluster_name = '$DBCLUST';"
$N1 = $SHOW.n1
$N2 = $SHOW.n2
$MYSQLROOT = $SHOW.mysql_root

if ($SHOW.status -like 'a*')
    {
        $ITEMKEYS = (Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select name, value from itemkeys where name in ('clientversion','eBOPackageVersion','ebourl','ecwserverversion','EMR_SrvProtocol','enablemedispan','faxinboxfromftp','faxserverhostname','faxserverip','faxservermacaddr');")
        $EBO_URL = ($ITEMKEYS|where {$_.name -eq 'ebourl'}).value #(Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'ebourl';").value
        $EBOVERSION = ($ITEMKEYS|where {$_.name -eq 'eBOPackageVersion'}).value #(Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'eBOPackageVersion';").value
        $MEDISPAN = ($ITEMKEYS|where {$_.name -eq 'enablemedispan'}).value #Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'enablemedispan';"
        $CLIENTVERSION = ($ITEMKEYS|where {$_.name -eq 'clientversion'}).value #(Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'clientversion';").value
        $SERVERVERSION = ($ITEMKEYS|where {$_.name -eq 'ecwserverversion'}).value #(Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'ecwserverversion';").value
        $NOW = (Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select now();").'now()'
        $MYSQLVERSION = (Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="show variables like 'version';").value
        $MYSQLENGINE = (Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="show variables like 'storage_engine';").value
        $PROVIDERS = (Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from users where usertype=1 and delFlag=0 and status=0;").'count(*)'
        if ($FAX)
            {
                $FAXDETAILS = ($ITEMKEYS|where {$_.name -like 'fax*'}) #Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select name,value from itemkeys where name in ('faxserverhostname','faxserverip','faxservermacaddr','faxinboxfromftp');"
            }
    }

#--Check if site is using SSL instead of plain HTTP
if (($ITEMKEYS|where {$_.name -eq 'EMR_SrvProtocol'}).value -like 'https*')
    {
        $SSL = $TRUE
    }
        else
            {
                $SSL = $FALSE
            }


#--Get external URL
$EXTURL = $SHOW.ext_url
#$GEUTEST = Test-Path $DRIVE\scripts\sources\ts01_privkey.ppk
#if ($GEUTEST -eq $true)
#    {
#        $EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01b "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"
#    }

#--Get the support provider
$SUPPORT = $SHOW.support_id
#write-host "DEBUG SUPPORT_ID: $SUPPORT"

[PSCustomObject] @{

'siteid'= $SHOW.siteid
'keywords' = $SHOW.keywords
'status' = $SHOW.status
'win_pwd' = $SHOW.win_pwd
'ftp_pwd' = $SHOW.ftp_pwd
'dsn_pwd' = $SHOW.dsn_pwd
'dbuser_pwd' = $SHOW.dbuser_pwd
'support_pwd' = $SHOW.support_pwd
'time_zone' = $SHOW.time_zone
'reseller_id' = $SHOW.reseller_id
'support_id' = $SUPPORT
'db_cluster' = $SHOW.db_cluster
'slave_server' = $SHOW.slave_server
'ftp_cluster' = $SHOW.ftp_cluster
'interface_server' = $tomcatC
'db_store_pt1' = $SHOW.db_store_pt1
'db_store_pt2' = $SHOW.db_store_pt2
'ebo_server' = $SHOW.ebo_server
'rdp_cluster' = $RDP_CLUSTER
'tomcatA' = $tomcatA
'tomcatB' = $tomcatB
'ClientVersion' = $CLIENTVERSION
'ServerVersion' = $SERVERVERSION
'Db_Name' = "mobiledoc_$SID (time: $NOW)"
'Db_Engine' = $MYSQLENGINE,$MYSQLVERSION
'APU_ID' = $SHOW.apu_id
'eBO_URL' = $EBO_URL
'eBO_Version' = $EBOVERSION
'BridgeIT' = $SHOW.bridge_it
'medispan' = $MEDISPAN
'providers' = $PROVIDERS
'External URL' = "https://$EXTURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
'SSL' = "$SSL"
                } #|Format-List

if ($TOOL)
    {
        [PSCustomObject] @{
            a1 = $SHOW.a1
            }
    }

if ($PATCH)
    {
        $PATCHES = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecwpatchid,status,patchdescription,seriesid from patcheslist order by ecwpatchid;"
    }
if ($INT)
    {
        $SDETAILS = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select IPAddress,MACAddress,PortNo,isDefaultJobServer from serverdetails order by id;"
    }
if ($LOGIN)
    {
        $ECWUSRLOG = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select usrname,serverlogintime,serverlogouttime,hostname,hostip,usrstatus,hostecwversion from usrlogs order by usrlogid desc limit 30;"
    }
if ($FOOTPRINT)
    {
        Write-Host "-- footprint --"
        $DBSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "du -hs /$MYSQLROOT/site$SID/mysql/data/mobiledoc_$SID"
        Write-Host "db_size: $DBSIZE"
        $FTPSITES = plink.exe -i \scripts\sources\ts01_privkey.ppk root@virtftp "/scripts/ffs -s=$SID"
        $FTPSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@virtftp "du -hs $FTPSITES/mobiledoc"
        Write-Host "ftp_size: $FTPSIZE"
        $APPSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "du -hs /alley/site$SID/tomcat$APP1_TC_VERSION/webapps/mobiledoc"
        Write-Host "app_size: $APPSIZE"
    }
if ($INT)
    {$SDETAILS.ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize}
if ($LOGIN)
    {$ECWUSRLOG.ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize}
if ($PATCH)
    {$PATCHES.ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize}
if ($FAX)
    {$FAXDETAILS.ForEach({[PSCustomObject]$_}) | Format-Table -AutoSize}