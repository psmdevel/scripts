#--Migrate MySQL instance to a different cluster

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module M:\scripts\sources\_functions.psm1 -Force

#--Get the hostname, tech, and tech email
$HOSTNAME = hostname
$TECH_ARRAY = @("andy@psmnv.com", "eric.robinson@psmnv.com", "joe.dilorenzo@psmnv.com", "ian.blauer@psmnv.com")
$TECHtmp = whoami
$TECH1 = $TECHtmp.split('\')[1]
if ($TECH1 -eq 'allean2') {$TECH = $TECH_ARRAY[0]}
if ($TECH1 -eq 'robier') {$TECH = $TECH_ARRAY[1]}
if ($TECH1 -eq 'dilojo') {$TECH = $TECH_ARRAY[2]}
if ($TECH1 -eq 'blauia') {$TECH = $TECH_ARRAY[3]}

#--Process the arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '--dbcluster' -or $L -eq '-d' ){$DBCLUST = $R}
            if ($L -eq '--install'){$INSTALL = $TRUE}
            if ($L -eq '--pause-afterdump'){$PAUSEAFTERDUMP = $TRUE}
            if ($L -eq '--skipdump'){$SKIPDUMP = $TRUE}
            if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Move mysql database to new cluster and reconfigure associated connections and services"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--dbcluster|-d' = "Specify the destination database cluster name"
                }|Format-List; exit
            }

#--Get the database cluster details
$DBDETAILS = Invoke-MySQL -Site 000 -Query "select * from db_clusters where cluster_name = '$DBCLUST';"
if (!$DBDETAILS)
    {
        Write-Output "Please specify a valid db_cluster name. $DBCLUST is not valid"
        exit
    }
#write-host "DEBUG: $DBDETAILS"
$N1 = $DBDETAILS.n1
$N2 = $DBDETAILS.n2
$MYSQLROOT = $DBDETAILS.mysql_root

#--Get the site information from ControlData
$SHOW = Show-Site --site=$m_SID --tool -p -l -x
#$SHOW = Invoke-MySQL -Site 000 -Query "select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$m_SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"

#--Get the terminal server info
$TS1 = $SHOW.t1
$TS2 = $SHOW.t2

#--Get the tomcat info
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

#--Get the DB info
$SRC_DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $m_SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$SRC_DBCLUSTIP = Test-Connection -computername $SRC_DBCLUST -count 1 | select Address,Ipv4Address
write-host "DEBUG: SRC_DBCLUSTIP - $SRC_DBCLUSTIP"
$SRC_DBCLUSTIP = $SRC_DBCLUSTIP.IPV4Address.IPAddressToString
$DBSTOREPT1 = ($SHOW.db_store_pt1).split(':')[0]
$SRC_MYSQLROOT = $SHOW.mysql_root
$DBSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$SRC_DBCLUST "du -hs /$SRC_MYSQLROOT/site$m_SID/mysql/data/mobiledoc_$m_SID"

#--Get the eBO info
$EBOSRV = $SHOW.ebo_server

#--Get the APU number and server
$APU = $SHOW.apu_id
#$ECWAPUAGENT = Invoke-my --site=$m_SID --host=$SRC_DBCLUST --query="select value from upgradeconfig where name = 'apuservicename';"
$APUAGENT = "ecwapuagent" + $APU
$APU06 = get-service -ComputerName apu06 -name $APUAGENT -ErrorAction SilentlyContinue
if ($APU06 -and $APU06.status -eq 'Running') 
    {$APUSRV = 'apu06';$APUSERVICE = get-service -ComputerName apu06 -name $APUAGENT}
        else 
            { if ($m_SID -gt 499) {$APUSRV = 'apu05';$APUSERVICE = get-service -ComputerName apu05 -name $APUAGENT}
                else
                    {$APUSRV = 'apu04';$APUSERVICE = get-service -ComputerName apu04 -name $APUAGENT}
    }

#--Get the m_INTERFACE info
$INT_SRV = $SHOW.a3
#Write-Host "DEBUG: Interface_Server = $INT_SRV"
if ($INT_SRV -like 'lab*')
    {
        $m_INTERFACE = '--INTERFACE'
        $INT_TOMCAT = gwmi -ComputerName $INT_SRV win32_service|?{$_.Name -eq "$m_SID"}|select name, displayname, startmode, state, pathname, processid
        $INT_TOMCATDIR = $INT_TOMCAT.pathname.split('\')[3]
    }

#--Get the appserver tomcats
if (Test-Path \\$APP1\site$m_SID\tomcat8) { $m_APP1TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$m_SID\tomcat7) { $m_APP1TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP1\site$m_SID\tomcat6) { $m_APP1TOMCATDIR = 'tomcat6' }
                        }
                }
if (Test-Path \\$APP2\site$m_SID\tomcat8) { $m_APP2TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP2\site$m_SID\tomcat7) { $m_APP2TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP2\site$m_SID\tomcat6) { $m_APP2TOMCATDIR = 'tomcat6' }
                        }
                }

#--Get the drug database info
$MEDISPAN = $SHOW.medispan
                if ($MEDISPAN -eq 'yes')
                    {
                        $FORMULARY = 'Medispan'
                        #--Find last Medispan update applied
                        $LASTFORM = (($SHOW).patches|where {$_.patchdescription -like 'medispan*' -and $_.status -eq 'complete'})[-1].ecwpatchid
                        #$VERSIONLIST | Add-Member -Type NoteProperty -Name Formulary -Value "$FORMULARY"
                        #$VERSIONLIST | Add-Member -Type NoteProperty -Name FormularyPatch -Value "$LASTFORM"
                    }
                        else
                            {
                                $FORMULARY = 'Multum'
                                #--Find last Medispan update applied
                                $LASTFORM = (($SHOW).patches|where {$_.patchdescription -like 'multum*' -and $_.status -eq 'complete'})[-1].ecwpatchid
                                #$VERSIONLIST | Add-Member -Type NoteProperty -Name Formulary -Value "$FORMULARY"
                                #$VERSIONLIST | Add-Member -Type NoteProperty -Name FormularyPatch -Value "$LASTFORM"
                            }

[PSCustomObject] @{
  Site     = $m_SID
  Appserver= $APP1, $APP2 
  Source_Cluster = $SRC_DBCLUST, $SRC_DBCLUSTIP 
  Dest_Cluster= $DBCLUST, $MYSQLROOT
  DbUser   = $DBUSER
  DB_PWD   = $DBPWD
  EBO      = $EBOSRV
  INTERFACE = $INT_SRV
  APU_ID   = $APU
  APUServer= $APUSRV, $APUAGENT
  Terminal = $TS1, $TS2
  Formulary = $FORMULARY,$LASTFORM
  DBSize = $DBSIZE
} | Format-list

#--Confirmation from user
Write-host -NoNewline " This will shut down all site services and migrate the database from $SRC_DBCLUST to $DBCLUST.
Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}

#--Enter scheduled downtime into planned_downtime table
planned_downtime --site=$m_SID --duration=4 --type=maint --proceed --capsule=000

#--shut down all the things

#Write-Output "DEBUG: safe_tomcat --site=$m_SID --stop --clear --fast --force --both $m_INTERFACE"
safe_tomcat --site=$m_SID --stop --clear --fast --force --both $m_INTERFACE
Write-host "Stopping APU Service on $APUSRV"
Stop-Service $APUSERVICE |Out-null
if ($EBOSRV)
        {
            Write-Host "Stopping eBO Service on $EBOSRV"
            ebomgr --site=$m_SID --stop
            #plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBOSRV "/scripts/ebomgr --site=$m_SID --stop"
        }

#--Perform the mysql backup
if (!$SKIPDUMP)
    {
        Write-Host "Taking mysql backup..."
        Connect-Ssh -ComputerName $DBCLUST -ScriptBlock "cd /$MYSQLROOT/site$m_SID/mysql/data;mysqldump -h$SRC_DBCLUST -P5$m_SID -u$DBUSER -p$DBPWD --compatible=no_table_options --single-transaction mobiledoc_$m_SID > mobiledoc_$m_SID.sql"
        Write-host -NoNewline "Done"
    }

#--Check the SQL dump to make sure it completed successfully
$DBSQLTEST = Connect-Ssh -ComputerName $DBCLUST -ScriptBlock "tail /$MYSQLROOT/site$m_SID/mysql/data/mobiledoc_$m_SID.sql"
if ($DBSQLTEST[-1] -like "*Dump completed*")
    {
        $DOTSQLTEST = "[SUCCESS]"
    }
        else
            {
                $DOTSQLTEST = "[ERROR]"
            }
Write-Host $DOTSQLTEST

#--Pause after sql dump
if ($PAUSEAFTERDUMP)
    {
        Write-host -NoNewline "Pausing after SQL dump, Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {}
    }

#--Perform the mysql import
Write-Host -NoNewline "Importing the mysql file..."
Connect-Ssh -ComputerName $DBCLUST -ScriptBlock "cd /$MYSQLROOT/site$m_SID/mysql/data;mysql -h$DBCLUST -P5$m_SID -u$DBUSER -p$DBPWD mobiledoc_$m_SID < mobiledoc_$m_SID.sql"
$IMPORTSUCCESS = Invoke-MySQL -Site $m_SID -Query "select value from upgradeconfig where name = 'apuservicename';"
if ($IMPORTSUCCESS.value -eq "$APUAGENT")
    {
        Write-Host "Done"
    }
        else
            {
                #--Email the tech re:import failure
                Send-MailMessage -To "$TECH <$TECH>" -From "migrate_mysql@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "MySQL Import for site$m_SID failed" -Body "MySQL Import for site$m_SID failed, please check script status"
                Write-Host -ForegroundColor Red "[FAILED]"
                Write-host -NoNewline "MySQL Import Failed, Enter 'PROCEED' to continue with post-import tasks anyway: "
                $RESPONSE = read-host
                if ($RESPONSE -cne 'PROCEED') {exit}
            }

#--Update sitetab
Invoke-MySQL -Site 000 -Query "update sitetab set db_cluster = '$DBCLUST' where siteid = '$m_SID' limit 1;"

#--Convert sensitive tables to InnoDB
$ITABLES = @('edi_facilities','edi_inspayments','edi_inv_cpt','edi_inv_diagnosis','edi_inv_eob','edi_inv_insurance','edi_invoice','edi_paymentdetail','users','doctors','patients','enc')
foreach ($T in (Invoke-MySQL -Site $m_SID -Query "select table_name from information_schema.tables where table_name in (select source_table from mobiledoc_$m_SID.interface_archive) and data_length > 0 and engine = 'myisam' or table_name in (select archive_table from mobiledoc_$m_SID.interface_archive) and data_length > 0 and engine = 'myisam' group by table_name ;
").table_name)
    {
        $ITABLES += $T
    }

foreach ($TABLE in $ITABLES)
    {
        Write-Host -NoNewline "Converting $TABLE to Innodb..."
        Invoke-MySQL -Site $m_SID -Update -Query "ALTER TABLE $TABLE ENGINE=InnoDB;"
        Write-Host " Done"
    }

#--Analyze tables post-import
Write-Host -NoNewline "Analyze tables in mobiledoc_$m_SID..."
analyze_mobiledoc.ps1 --site=$m_SID|Out-Null
<#$MOBILEDOCTABLES = Invoke-MySQL -Site $m_SID -Query "select table_name from information_schema.tables where table_schema = 'mobiledoc_$m_SID';"
foreach  ($TABLE in $MOBILEDOCTABLES.table_name)
    {
        Invoke-MySQL -Site $m_SID -Query "analyze table $TABLE;"|Out-Null
    }#>
Write-Host " Done"

#--Drop EPCS triggers if they exist
Write-Host -NoNewline "Dropping EPCS triggers if they exist to prevent excessive warnings to practice admins..."
Invoke-MySQL -Site $m_SID -Update -Query "DROP TRIGGER IF EXISTS `Update_EPCS_Reports` ; DROP TRIGGER IF EXISTS `Delete_EPCS_Reports` ; DROP TRIGGER IF EXISTS `Update_EPCS_Reportsdetail` ; DROP TRIGGER IF EXISTS `Delete_EPCS_Reportsdetail` ; DROP TRIGGER IF EXISTS `Update_EPCS_Scriptlog` ; DROP TRIGGER IF EXISTS `Delete_EPCS_Scriptlog` ; DROP TRIGGER IF EXISTS `Update_EPCS_trigerlogs` ; DROP TRIGGER IF EXISTS `Delete_EPCS_trigerlogs` ; DROP TRIGGER IF EXISTS `Update_EPCS_Usersactivitylogs` ; DROP TRIGGER IF EXISTS `Delete_EPCS_Usersactivitylogs` ;"
Write-Host " Done"



#--Update the mobiledoccfg.properties on all tomcats

Write-Host "Updating mobiledoccfg.properties on $APP1"
$MOBILECFG1 = Get-Content \\$APP1\site$m_SID\$m_APP1TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties|Select-String "mobiledoc.DBUrl"
#write-host "DEBUG: $MOBILECFG1"
if ($MOBILECFG1 -like "*$SRC_DBCLUST*")
    {
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$m_SID/$m_APP1TOMCATDIR/webapps/mobiledoc/conf;sed -i 's/$SRC_DBCLUST/$DBCLUST/g' mobiledoccfg.properties"
        if ($MEDISPAN -eq 'yes')
            {
                plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$m_SID/$m_APP1TOMCATDIR/webapps/mobiledoc/WEB-INF/classes/;sed -i 's/$SRC_DBCLUST/$DBCLUST/g' medispan.wkconfig.xml"
            }
    }
        else
            {
                plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$m_SID/$m_APP1TOMCATDIR/webapps/mobiledoc/conf;sed -i 's/$SRC_DBCLUSTIP/$DBCLUST/g' mobiledoccfg.properties"
                if ($MEDISPAN -eq 'yes')
                    {
                        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$m_SID/$m_APP1TOMCATDIR/webapps/mobiledoc/WEB-INF/classes/;sed -i 's/$SRC_DBCLUSTIP/$DBCLUST/g' medispan.wkconfig.xml"
                    }
            }

Write-Host "Updating mobiledoccfg.properties on $APP2"
$MOBILECFG2 = Get-Content \\$APP2\site$m_SID\$m_APP2TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties|Select-String "mobiledoc.DBUrl"
if ($MOBILECFG2 -like "*$SRC_DBCLUST*")
    {
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$m_SID/$m_APP2TOMCATDIR/webapps/mobiledoc/conf;sed -i 's/$SRC_DBCLUST/$DBCLUST/g' mobiledoccfg.properties"
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$m_SID/$m_APP2TOMCATDIR/webapps/mobiledoc/WEB-INF/classes/;sed -i 's/$SRC_DBCLUST/$DBCLUST/g' medispan.wkconfig.xml"
    }
        else
            {
                plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$m_SID/$m_APP2TOMCATDIR/webapps/mobiledoc/conf;sed -i 's/$SRC_DBCLUSTIP/$DBCLUST/g' mobiledoccfg.properties"
                plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$m_SID/$m_APP2TOMCATDIR/webapps/mobiledoc/WEB-INF/classes/;sed -i 's/$SRC_DBCLUSTIP/$DBCLUST/g' medispan.wkconfig.xml"
            }

if ($INT_SRV)
    {
        Write-Host "Updating mobiledoccfg.properties on $INT_SRV"
        $MOBILECFG_INT = Get-Content \\$INT_SRV\c$\alley\site$m_SID\$INT_TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties|Select-String "mobiledoc.DBUrl"
        if ($MOBILECFG_INT -like "*$SRC_DBCLUST*")
            {
                Replace-FileString.ps1 -pattern "$SRC_DBCLUST" -replacement $DBCLUST -path \\$INT_SRV\c$\alley\site$m_SID\$INT_TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
                Replace-FileString.ps1 -pattern "$SRC_DBCLUST" -replacement $DBCLUST -path \\$INT_SRV\c$\alley\site$m_SID\$INT_TOMCATDIR\webapps\mobiledoc\WEB-INF\classes\medispan.wkconfig.xml -overwrite
            }
                else
                    {
                        Replace-FileString.ps1 -pattern "$SRC_DBCLUSTIP" -replacement $DBCLUST -path \\$INT_SRV\c$\alley\site$m_SID\$INT_TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
                        Replace-FileString.ps1 -pattern "$SRC_DBCLUSTIP" -replacement $DBCLUST -path \\$INT_SRV\c$\alley\site$m_SID\$INT_TOMCATDIR\webapps\mobiledoc\WEB-INF\classes\medispan.wkconfig.xml -overwrite
                    }
    }

#--Update APU server DSN entry
Write-Host "Updating DSN on $APUSRV..."
Invoke-Command -ComputerName $APUSRV -ScriptBlock {set-ItemProperty HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:m_SID -name Server -value $using:DBCLUST}

#--Update Terminal server DSN entries
Write-Host "Updating DSN on $TS1..."
Invoke-Command -ComputerName $TS1 -ScriptBlock {set-ItemProperty HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:m_SID -name Server -value $using:DBCLUST}
Write-Host "Updating DSN on $TS2..."
Invoke-Command -ComputerName $TS2 -ScriptBlock {set-ItemProperty HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:m_SID -name Server -value $using:DBCLUST}

#--Ensure SSH from new cluster to db_store_pt1
plink -i M:\scripts\sources\ts01_privkey.ppk root@$DBCLUST "/scripts/setup_ssh -d=$DBSTOREPT1"

#--Import latest formulary sql file
plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "/scripts/medpatch --site=$m_SID -b"
if ($FORMULARY -eq 'medispan')
    {
        analyze_medispan.ps1 --site=$m_SID
    }

#--Restart all the things
safe_tomcat --site=$m_SID --restart --both --force $m_INTERFACE
Write-host "Starting APU Service on $APUSRV"
restart-Service $APUSERVICE|Out-null

#--Email the tech re:success
Send-MailMessage -To "$TECH <$TECH>" -From "migrate_mysql@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "MySQL Import for site$m_SID completed" -Body "MySQL Import for site$m_SID completed. "
#--Display message reminding tech to update eBO and load balancer entries
Write-Host "Migration complete. Please update eBO odbc.ini & eBO_JDBC_Config.properties entries, and the mysql load balancer entry"