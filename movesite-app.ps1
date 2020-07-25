#--movesite-app

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
            if ($L -eq '--to' -or $L -eq '-t') {$TO_CLUST = $R}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Moves apps from current cluster to specified app cluster ID'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--to|-t' = 'Specify the destination app cluster ID'
                }|Format-List; exit
            }

#--verify arguments
$m_SHOW  = invoke-mysql -s=000 --query="select * from sitetab where siteid = $m_SID;"
#--verify siteid exists and is active
if ($m_SHOW.status -like 'i%')
    {
        write-host "Site is inactive. Please specify an active site";exit
    }
#--get the FROM cluster and app servers, nodes, ip's
$F_APPCID = $m_SHOW.app_cluster_id[0]
$F_APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $F_APPCID;"
$F_APP1 = $F_APPID.a1
$F_APP2 = $F_APPID.a2
if (!$F_APP1 -or !$F_APP2)
    {
        Write-Host "Could not determine names of source appservers";exit
    }
$F_APP1_IP = (Test-Connection -computername $F_APP1 -count 1 | select Address,Ipv4Address).IPV4Address.IPAddressToString
$F_APP2_IP = (Test-Connection -computername $F_APP2 -count 1 | select Address,Ipv4Address).IPV4Address.IPAddressToString
#--Get site DB information
$DBCLUST = $m_SHOW.db_cluster
$DBUSER = "site" + $m_SID + "_DbUser"
$DBPWD = $m_SHOW.dbuser_pwd
#invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="UPDATE securitykeys SET VALUE = 'no' WHERE NAME = 'EnableSecondCookieCheck';"
#--verify the TO cluster exists
if (-not (invoke-mysql -s=000 --query="select id from app_clusters where id='$TO_CLUST';").id)
    {
        write-host "Destination app_cluster_id does not exist"
    }
#--verify requested cluster is not full
if ((invoke-mysql -s=000 --query="select id from app_clusters where id='$TO_CLUST';").is_full -eq 'yes')
    {
        Write-Host "Destination app_cluster is full";exit
    }

#--get the app servers in the TO cluster
$T_APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $TO_CLUST;"
$T_APP1 = $T_APPID.a1
$T_APP2 = $T_APPID.a2
if (!$T_APP1 -or !$T_APP2)
    {
        Write-Host "Could not determine names of destination appservers";exit
    }

#--get the tomcat root folder for the FROM cluster
$F_APP1_TOMCAT = "tomcat" + (plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP1 "ls -1 /alley/site$m_SID|grep tomcat|sort|sed 's/tomcat//g'|head -1")
$F_APP2_TOMCAT = "tomcat" + (plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP2 "ls -1 /alley/site$m_SID|grep tomcat|sort|sed 's/tomcat//g'|head -1")
#--get the tomcat root folder for the TO cluster
$T_TOMCAT = (Invoke-MySQL -s=000 --query="select * from app_clusters where id = $TO_CLUST;").tomcat_folder
#--get the tomcat user name
$F_UID = plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP1 "grep site$m_SID /etc/passwd|cut -d':' -f3"

#--verify connectivity to FA2
plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP1 "setup_ssh -d=$F_APP2"

#--verify connectivity to TO servers
plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP1 "setup_ssh -d=$T_APP1"
plink -i \scripts\sources\ts01_privkey.ppk root@$F_APP1 "setup_ssh -d=$T_APP2"

#--confirm move

echo "#####################################################"
echo "##                                                 ##"
echo "##            Move App Server Instance             ##"
echo "##                                                 ##"
echo "#####################################################"

echo "       site: $m_SID"
echo "        uid: $F_UID"
echo "       from: $F_APP1, $F_APP2 (/alley/site$m_SID/$F_APP1_TOMCAT)"
echo "         to: $T_APP1, $T_APP2 (/alley/site$m_SID/$T_TOMCAT)"

#--Confirmation from user
Write-host -NoNewline "move app server instance for site$m_SID`?

Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}


#--safely stop the tomcat instances on FA1,FA2
safe_tomcat.ps1 --site=$m_SID --stop --clear --fast --force --a

#--zip up a copy of the webapps folder on FA1
$TODAY = Get-Date -Format yyyy_MMdd
Write-Host "zipping /alley/site$m_SID/$F_APP1_TOMCAT/webapps folder on $F_APP1" 
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "cd /alley/site$m_SID/$F_APP1_TOMCAT;zip -r webapps-preMove-$TODAY.zip webapps > /dev/null"

#--verify the target folder does not already exist on T_APP1
if (plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "find /alley -maxdepth 1 -name site$m_SID")
    {
        write-host "error: folder '/alley/site$m_SID' already exists on $T_APP1"
    }
#--copy the template folder
write-host "copying template folder /alley/_template to /alley/site$m_SID on $T_APP1"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "cp -R /alley/_template /alley/site$m_SID"

#--update the server.xml file
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "cd /alley/site$m_SID/$T_TOMCAT/conf;sed -i 's/XXX/$m_SID/g' server.xml"

#--bring over the tomcat-env.sh
write-host "copying tomcat-env.sh to $T_APP1"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "scp -q /alley/site$m_SID/$F_APP1_TOMCAT/conf/tomcat-env.sh $T_APP1`:/alley/site$m_SID/$T_TOMCAT/conf"

#--bring over catalina.properties
write-host "copying catalina.properties to $T_APP1"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "scp -q /alley/site$m_SID/$F_APP1_TOMCAT/conf/catalina.properties $T_APP1`:/alley/site$m_SID/$T_TOMCAT/conf"

#--bring over the XML files
write-host "copying xml config files"
setperms --site=$m_SID -a --unlock
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "scp -rq /alley/site$m_SID/$F_APP1_TOMCAT/conf/Catalina/localhost $T_APP1`:/alley/site$m_SID/$T_TOMCAT/conf/Catalina/"

#--transfer the zipped webapps folder
write-host "transferring the zipped webapps folder"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "scp -q /alley/site$m_SID/$F_APP1_TOMCAT/webapps-preMove-$TODAY.zip $T_APP1`:/alley/site$m_SID/$T_TOMCAT"
$TESTZIP1 = plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "ls -l /alley/site$m_SID/$F_APP1_TOMCAT/webapps-preMove-$TODAY.zip"
$TESTZIP2 = plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "ls -l /alley/site$m_SID/$F_APP1_TOMCAT/webapps-preMove-$TODAY.zip"
if ($TESTZIP1.split(' ')[4] -ne $TESTZIP2.split(' ')[4])
    {
        write-host "error: webapps-preMove-$TODAY.zip was not transferred successfully; aborting";exit
    }

#--run chkckonfig --off on FROM servers
write-host "running 'chkconfig tomcat_$m_SID off' on $F_APP1"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP1 "chkconfig 'tomcat_$m_SID' off"
write-host "running 'chkconfig tomcat_$m_SID off' on $F_APP2"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$F_APP2 "chkconfig 'tomcat_$m_SID' off"

#--create init scripts on the TO servers
#--create a new service entry
Write-Host "creating new tomcat_$m_SID service entries "
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "cd /etc/init.d;ln -s tomcat_multi 'tomcat_$m_SID'"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "cd /etc/init.d;ln -s tomcat_multi 'tomcat_$m_SID'"

plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "chkconfig --add tomcat_$m_SID"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "chkconfig tomcat_$m_SID on"

plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "chkconfig --add tomcat_$m_SID"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "chkconfig tomcat_$m_SID on"

#--add user accounts to the target servers if necessary
write-host "adding user accounts to target servers if necessary"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "adduser site$m_SID -u $F_UID -s /sbin/nologin 2> /dev/null"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "adduser site$m_SID -u $F_UID -s /sbin/nologin 2> /dev/null"

#--unzip the file
write-host "unzipping the webapps folder"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "cd /alley/site$m_SID/$T_TOMCAT;unzip -oq webapps-preMove-$TODAY.zip"

#--rsync the directory to the other new server
write-host "rsyncing /alley/site$m_SID from $T_APP1 to $T_APP2"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "rsync -avhq /alley/site$m_SID $T_APP2`:/alley --exclude=*.zip --exclude=*.txt --exclude=*.log"


#--get the mobiledoccfg.properties file for the second server
write-host "get the second mobiledoccfg.properties file"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "scp -q $F_APP2`:/alley/site$m_SID/$F_APP1_TOMCAT/webapps/mobiledoc/conf/mobiledoccfg.properties /alley/site$m_SID/$T_TOMCAT/webapps/mobiledoc/conf"

#--update sitetab
invoke-mysql -s=000 --query="update sitetab set app_cluster_id='$TO_CLUST' where siteid='$m_SID' limit 1;"
#--set permissions
setperms --site=$m_SID --both

#--Clear app server entries from serverdetails
invoke-mysql --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="delete from serverdetails where ipaddress = '$F_APP1_IP';"
invoke-mysql --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="delete from serverdetails where ipaddress = '$F_APP2_IP';"

#--echo done
write-host "done; you may start tomcat."

write-host "Be sure to (1) edit /etc/samba/smb.conf, (2) change the load balancer!"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP1 "/scripts/fix_samba"
plink -i M:\scripts\sources\ts01_privkey.ppk root@$T_APP2 "/scripts/fix_samba"
