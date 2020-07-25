#--Reconfigure APU tool to point at application tomcat instead of local dummy tomcat, and run Autoupgrade_dev_v2.exe
#--Script to be run from APU server hosting the APU service for the specified practice

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Reconfigure APU tool to point at application tomcat instead of local dummy tomcat, and run Autoupgrade_dev_v2.exe"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number"
                }|Format-List; exit
            }

#--Get the site info from control database
$SHOW  = Invoke-MySQL --site=000 --query="select * from sitetab where siteid = $m_SID;"
if ($SHOW.status -like 'i*')
    {
        Write-Output "Site$m_SID is inactive. Please choose an active site. Exiting";exit
    }
$SID = $SHOW.siteid
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + '_DbUser'
$DBPWD = $SHOW.dbuser_pwd
$APPCID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $APPID.a1
$APP2 = $APPID.a2

#--Get info from site database
$APUSERVICE = (Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from upgradeconfig where name = 'apuservicename';").value
#$APUSERVICE = $UPGRADECONFIG.apuservicename.value
$TOMCATSERVICE = (Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from upgradeconfig where name = 'tomcatservicename';").value #($UPGRADECONFIG.tomcatservice)
$WEBHOME = "c:\\eClinicalWorks\\$TOMCATSERVICE"
$WEBHOME2 = (Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from upgradeconfig where name = 'webhome';").value
#write-host "DEBUG: APU SERVICE = $APUSERVICE"
if ((Get-Service $APUSERVICE).status -ne 'Running')
    {
        Write-Output "Service $APUSERVICE not running on $HOSTNAME. Exiting";exit
    }

#--Get the current config
$CONFIGFILE = "C:\sites\$m_SID\AutoPracticeUpgrade\AutoUpgrade_Dev.exe.config"
[xml]$CONFIG = Get-Content $CONFIGFILE
$node1 = $CONFIG.configuration.appSettings.add|Where-Object {$_.key -eq "tomcathome"}
$node2 = $CONFIG.configuration.appSettings.add|Where-Object {$_.key -eq "tomcatservice"}
$node3 = $CONFIG.configuration.appSettings.add|Where-Object {$_.key -eq "serverurl"}

#--Update the config
$node1.value = "\\$APP1\site$m_SID\tomcat7"
$node2.value = "tomcat7"
$node3.value = "http://$APP1`:3$m_SID"
$CONFIG.save("$CONFIGFILE")


#--Test the new config
[xml]$CONFIG2 = Get-Content $CONFIGFILE
#($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "tomcathome"}).value
#($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "tomcatservice"}).value
#($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "serverurl"}).value
if (($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "tomcathome"}).value -ne "\\$APP1\site$m_SID\tomcat7")
    {
        write-host "AutoUpgrade_Dev.exe.config TomcatHome not updated correctly"
        if (($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "tomcatservice"}).value -ne "tomcat7")
            {
                write-host "AutoUpgrade_Dev.exe.config TomcatService not updated correctly"
                if (($CONFIG2.configuration.appSettings.add|Where-Object {$_.key -eq "serverurl"}).value -ne "http://$APP1`:3$m_SID")
                    {
                        write-host "AutoUpgrade_Dev.exe.config ServerUrl not updated correctly";exit
                    }
            }
    
        #Write-Output "$CONFIGFILE not updated correctly. Exiting";exit
    }

#--Update the upgradeconfig table to match the new(temporary) values
Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update upgradeconfig set value = '\\\\$APP1\\site$m_SID\\tomcat7' where name = 'webhome' limit 1;"
Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update upgradeconfig set value = 'tomcat7' where name = 'tomcatservicename' limit 1;"
if ((Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from upgradeconfig where name = 'webhome';").value -ne "\\$APP1\site$m_SID\tomcat7")
    {
        Write-Output "Upgradeconfig webhome not updated correctly. Exiting";exit
    }
if ((Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from upgradeconfig where name = 'tomcatservicename';").value -ne "tomcat7")
    {
        Write-Output "Upgradeconfig tomcatservice not updated correctly. Exiting";exit
    }

#--Launch AutoUpgrade_Dev_V2.exe
$CWD = $PWD.Path
cd C:\sites\$m_SID\AutoPracticeUpgrade\
Write-Host "Launching C:\sites\$m_SID\AutoPracticeUpgrade\AutoUpgrade_Dev_V2.exe"
& "C:\sites\$m_SID\AutoPracticeUpgrade\AutoUpgrade_Dev_V2.exe"
get-process autoupgrade_dev_v2|Where-Object {$_.path -like "*$m_SID*"}|Wait-Process
#Start-Job -Name APUV2$m_SID {& "C:\sites\$using:m_SID\AutoPracticeUpgrade\AutoUpgrade_Dev_V2.exe"}
#get-job APUV2$m_SID|Wait-Job
cd $CWD

#--Put everything back
Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update upgradeconfig set value = '$WEBHOME' where name = 'webhome' limit 1;"
Invoke-MySQL --site=$m_SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update upgradeconfig set value = '$TOMCATSERVICE' where name = 'tomcatservicename' limit 1;"

#--Update the config (again)
$node1.value = "$WEBHOME2"
$node2.value = "$TOMCATSERVICE"
$node3.value = "http://localhost:8080"
$CONFIG.save("$CONFIGFILE")

#--Test the Final config
[xml]$CONFIG3 = Get-Content $CONFIGFILE
if (($CONFIG3.configuration.appSettings.add|Where-Object {$_.key -eq "tomcathome"}).value -ne "$WEBHOME2") 
    {
        Write-Host "tomcathome not reverted correctly"
        if (($CONFIG3.configuration.appSettings.add|Where-Object {$_.key -eq "tomcatservice"}).value -ne "$TOMCATSERVICE") 
            {
                Write-Host "tomcatservice not reverted correctly"
                if (($CONFIG3.configuration.appSettings.add|Where-Object {$_.key -eq "serverurl"}).value -ne "http://localhost:8080")
                    {
                        Write-Host "serverurl not reverted correctly"
                        Write-Output "$CONFIGFILE not updated correctly. Exiting";exit
                    }
            }
    }