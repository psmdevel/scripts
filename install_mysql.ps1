#--Install MySQL service on specified dbcluster

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module M:\scripts\sources\_functions.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
            if ($L -eq '--dbcluster' -or $L -eq '-d' ){$DBCLUST = $R}
            if ($L -eq '--dbtype' ){$DBTYPE = $R}
            if ($L -eq '--slave' ){$SLAVE = $TRUE}
            if ($L -eq '--skipcopy' ){$SKIPCOPY = $TRUE}
            if ($L -eq '--skipuser' ){$SKIPUSER = $TRUE}
            if ($L -eq '--slave' ){$SLAVE = $TRUE}
            if ($L -eq '--force' -or $L -eq '-f' ){$FORCE = $TRUE}
            if ($L -eq '--proceed' -or $L -eq '-y' ){$PROCEED = $TRUE}
            if ($L -eq '--help' -or $L -eq '-h'){$HELP = 'True'}
    }


#--Help
if ($HELP) {
[PSCustomObject] @{
'--help or -h' = "Display this message"
'--site or -s' = "Specify the site number"
'--dbcluster or -d' = "Install mysql server on this cluster"
'--dbtype' = "Specify InnoDB or MyISAM, 'i' or 'm'"
'--slave' = "Specify that this is a slave server setup"
'--force|-f' = "Proceed despite exceptions (hope you know what you're doing)"
                }|Format-List; exit
            }

#Write-Host "DEBUG: $DBTYPE";exit

#--Get the list of database servers
$DBDETAILS = Invoke-MySQL -Site 000 -Query "select * from db_clusters where cluster_name = '$DBCLUST';"
#write-host "DEBUG: $DBDETAILS"
$N1 = $DBDETAILS.n1
$N2 = $DBDETAILS.n2
if ($SLAVE)
    {
        $MYSQLROOT = '/slaves'
    }
        else
            {
                $MYSQLROOT = $DBDETAILS.mysql_root
            }


$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}
$CURRENTDB = $SHOW.db_cluster
if ($CURRENTDB -eq $DBCLUST){Write-Host "Cannot install mysql service on this cluster as it is already installed";exit}
#write-host "DEBUG: $CURRENTDB"
$UPWD = $SHOW.dsn_pwd
$DBPWD = $SHOW.dbuser_pwd
$DBUSER = "site" + $SID + "_DbUser"
$Auth = get-Auth

#--Set Database Engine
if ($DBTYPE)
    {
        if ($DBTYPE -ne 'i' -or $DBTYPE -ne 'InnoDB' -or $DBTYPE -ne 'm' -or $DBTYPE -ne 'MyISAM')
            {
                Write-Host "Please specify --dbtype = 'InnoDB' or 'MyISAM'";exit
            }
    }
if (!$DBTYPE)
    {$ENGINE = "myisam"}
        else
            {
                if ($DBTYPE -eq 'i' -or $DBTYPE -eq 'InnoDB'){$ENGINE = 'innodb'}
                if ($DBTYPE -eq 'm' -or $DBTYPE -eq 'MyISAM'){$ENGINE = 'myisam'}

            }

#--Set UID
$SIDUID = [int]$SID + 500

#--Check if mysql userid already exists
$CHECKUSRIDN1 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "getent passwd '$SIDUID'|cut -d: -f1"
$CHECKUSRIDN2 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "getent passwd '$SIDUID'|cut -d: -f1"

#--Check if mysql already exists or install already in progress
$CHECKUSRN1 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "id -u site$SID"
$CHECKUSRN2 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "id -u site$SID"
$CHECKSITEFOLDER = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT;ls site$SID"
if ($SLAVE)
    {
        $CHECKSYMLN1 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "cd /etc/init.d;ls slave_$SID"
        $CHECKSYMLN2 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "cd /etc/init.d;ls slave_$SID"

    }
        else
            {
                $CHECKSYMLN1 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "cd /etc/init.d;ls mysql_$SID"
                $CHECKSYMLN2 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "cd /etc/init.d;ls mysql_$SID"
            }
if ($CHECKSITEFOLDER)
    {$CHECKMYCNF = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/site$SID/mysql/;ls my.cnf"}

#--Exception list
If ($CHECKUSRN1 -or $CHECKUSRN2 -or $CHECKSITEFOLDER -or $CHECKSYMLN1 -or $CHECKSYMLN2 -or $CHECKMYCNF -or $CHECKUSRIDN1 -or $CHECKUSRIDN2)
    {
        [PSCustomObject] @{
        'User account on N1' = "site$SID, $CHECKUSRN1, $CHECKUSRIDN1"
        'User account on N2' = "site$SID, $CHECKUSRN2, $CHECKUSRIDN2"
        'Site folder found' = "$MYSQLROOT/site$SID/$CHECKSITEFOLDER"
        'Service Symlink on N1' = "$CHECKSYMLN1"
        'Service Symlink on N2' = "$CHECKSYMLN2"
        'My.cnf found' = "$CHECKMYCNF"
        'Force install' = "$FORCE"

                        }|Format-List
            if (!$FORCE)
                {
                    write-output "Exceptions found indicate service already installed or installation in progress. Please address exceptions before proceeding";exit
                }
                    else
                        {
                            Write-Output "Force specified, proceeding despite exceptions"
                        }
    }


$TZ = $SHOW.time_zone
$TIME_ARRAY = @("Los_Angeles", "Honolulu", "Denver", "Chicago", "New_York")
IF ($TZ -eq "PST") { $TIME_ZONE =  $TIME_ARRAY[0] }
IF ($TZ -eq "HST") { $TIME_ZONE =  $TIME_ARRAY[1] }
IF ($TZ -eq "MST") { $TIME_ZONE =  $TIME_ARRAY[2] }
IF ($TZ -eq "CST") { $TIME_ZONE =  $TIME_ARRAY[3] }
IF ($TZ -eq "EST") { $TIME_ZONE =  $TIME_ARRAY[4] }

#--Set /ha0X_mysql
if ($MYSQLROOT -eq 'ha01_mysql'){$HA = '01'}
if ($MYSQLROOT -eq 'ha02_mysql'){$HA = '02'}

#--Check for special mysql user accounts on old database
$USERS = (Invoke-MySQL -ServerName $CURRENTDB -Site $SID -Query "select count(*) from mysql.user where user not in ('root','root_sa','site$SID','site$SID`_DbUser','repl_user');").'count(*)'

#--Display
[PSCustomObject] @{
'Site' = "site$SID"
'Slave' = "$SLAVE"
'Destination Server' = "$DBCLUST"
'Nodes' = "$N1,$N2"
'UserID' = $SIDUID
'HA Directory' = "$MYSQLROOT"
'Time Zone' = "$TIME_ZONE"
'MySQL Engine' = "$ENGINE"
'Special Accounts' = $USERS
                }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting install..."}

#--Check if an installation is already in progress
#$TESTUSERN1 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "id -u site$SID"
#$TESTUSERN2 = plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "id -u site$SID"

if (!$SKIPCOPY)
{
    #--Create site folder from _template
    if ($SLAVE)
        {
            plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT; cp -R _template slave$SID"
        }
            else
                {
                    plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT; cp -R _template site$SID"
                }
}

if (!$SKIPUSER)
    {
        #--Create user accounts
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "adduser site$SID -u $SIDUID -s /bin/bash"
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "adduser site$SID -u $SIDUID -s /bin/bash"
    }

#--Create mysql service symlinks
if ($SLAVE)
    {
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "cd /etc/init.d;ln -s mysql_multi slave_$SID"
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "cd /etc/init.d;ln -s mysql_multi slave_$SID"

    }
        else
            {
                plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N1 "cd /etc/init.d;ln -s mysql_multi mysql_$SID"
                plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$N2 "cd /etc/init.d;ln -s mysql_multi mysql_$SID"
            }

#--Create and edit my.cnf file
if ($SLAVE)
    {
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/slave$SID/mysql/;cat my.cnf.$ENGINE > my.cnf;sed -i 's/XXX/$SID/g' my.cnf;sed -i 's/0X/$HA/g' my.cnf;sed -i 's/ZZZ/$TIME_ZONE/g' my.cnf;sed -i 's/site$SID/slave$SID/g' my.cnf"
        if ($TZ -eq 'HST'){plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/slave$SID/mysql/;sed -i 's/timezone=America/timezone=Pacific/g' my.cnf"}
    }
        else
            {
                plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/site$SID/mysql/;cat my.cnf.$ENGINE > my.cnf;sed -i 's/XXX/$SID/g' my.cnf;sed -i 's/0X/$HA/g' my.cnf;sed -i 's/ZZZ/$TIME_ZONE/g' my.cnf"
                if ($TZ -eq 'HST'){plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/site$SID/mysql/;sed -i 's/timezone=America/timezone=Pacific/g' my.cnf"}
            }

#--Move the mobiledoc template database, setdbperms, and start service
if ($SLAVE)
    {
        plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/slave$SID/mysql/data;mv mobiledoc_xxx mobiledoc_$SID;/scripts/setdbperms --slave=$SID;service slave_$SID start"
    }
        else
            {
                plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd /$MYSQLROOT/site$SID/mysql/data;mv mobiledoc_xxx mobiledoc_$SID;/scripts/setdbperms --site=$SID;service mysql_$SID start"
            }

#--Wait a moment for the service to start
do 
    {
          Write-Host "waiting for service to start..."
          sleep 3      
    } 
        until
            (Test-NetConnection $DBCLUST -Port 5$SID | ? { $_.TcpTestSucceeded } )
#Write-Output "Pausing for service to start..."
#Timeout 30|Out-Null

#--Update user and DbUser accounts
Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Credential $Auth -Database mobiledoc_$SID
Invoke-SqlUpdate -Query "update mysql.user set user = 'site$SID' where user = 'siteXXX' limit 1;"
Invoke-SqlUpdate -Query "update mysql.user set user = 'site$SID`_DbUser' where user = 'siteXXX_DbUser' limit 1;"
Invoke-SqlUpdate -Query "update mysql.user set password = password('$UPWD') where user = 'site$SID' limit 1;"
Invoke-SqlUpdate -Query "update mysql.user set password = password('$DBPWD') where user = 'site$SID`_DbUser' limit 1;"
Invoke-SqlUpdate -Query "grant all on *.* to 'site$SID`_DbUser'@'%';"
Invoke-SqlUpdate -Query "flush privileges;"
$TESTCOMPLETE = Invoke-SqlQuery -Query "select super_priv from mysql.user where user = 'site$SID`_DbUser';"
if ($TESTCOMPLETE.super_priv -eq 'y')
    {write-host "MySQL install on $DBCLUST for site$SID is complete."}
        else
            {write-host "MySQL install on $DBCLUST for site$SID finished with errors."}
Close-SqlConnection