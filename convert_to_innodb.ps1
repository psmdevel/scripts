#--InnoDB Conversion for standard or specified table(s)

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '--TABLE' -or $L -eq '-T' ){$S_TABLE = $R}
            if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
            if ($ARG -eq '--slave'){$USESLAVE = $TRUE}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Convert standard tables or a specified table to InnoDB"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--table|-t' = "Specify a single table"
                }|Format-List; exit
            }

#--Get site info
$SHOW = Show-Site --site=$m_SID --tool
$Auth_SID = $SHOW.auth_sid
#Write-Host "debug: auth_sid"$Auth_SID

#$SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$m_SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"
if ($USESLAVE)
    {
        if ($SHOW.slave_server -like 'slave*' -or $SHOW.slave_server -like 'dbclust*')
            {
                $DBCLUST = $SHOW.slave_server
            }
                else
                    {
                        Write-Host "Slave server specified, but site does not have a slave database. Exiting"
                        exit
                    }
    }
        else
            {
                $DBCLUST = $SHOW.db_cluster
            }
$DBUSER = "site" + $m_SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--see if snapshots are enabled
if (!$USESLAVE)
    {
        $LVDISPLAY_CMD = plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "/usr/bin/which lvdisplay"
        $SNAPS = plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST "$LVDISPLAY_CMD|grep drbd|grep lv"
        if (!$SNAPS)
                    {
                        Write-Host "Snapshots not enabled for specified dbcluster, exiting.";exit
                    }
    }

#--Ensure Innodb_file_per_table is enabled
Open-MySqlConnection -Server $DBCLUST -Port 5$m_SID -Database mobiledoc_$m_SID -Credential $Auth_SID -CommandTimeout 0
$CHECK_INNODBFPT = Invoke-SqlQuery -Query "show variables like 'innodb_file_per_table';"
if ($CHECK_INNODBFPT.value -ne 'ON')
    {
        Write-Host "InnoDB_file_per_table not enabled. Please enable and try again.";exit
    }

if ($S_TABLE)
    {
        $TABLES = $S_TABLE
    }
        else
            {
                $TABLES = 'Standard'
            }

#--Get tables to convert
if ($S_TABLE)
    {
        $ITABLES = $S_TABLE
    }
        else
            {
                $ITABLES = @('edi_facilities','edi_inspayments','edi_inv_cpt','edi_inv_diagnosis','edi_inv_eob','edi_inv_insurance','edi_invoice','edi_paymentdetail','users','doctors','patients','enc')
                foreach ($T in (Invoke-SqlQuery -Query "select table_name from information_schema.tables where table_name in (select source_table from mobiledoc_$m_SID.interface_archive) and data_length > 0 and engine = 'myisam' or table_name in (select archive_table from mobiledoc_$m_SID.interface_archive) and data_length > 0 and engine = 'myisam' group by table_name ;
                ").table_name)
                    {
                        $ITABLES += $T
                    }
            }

[PSCustomObject] @{
  Site     = $m_SID
  DbCluster = $DBCLUST
  Tables = $TABLES 
  FilePerTable = $CHECK_INNODBFPT.value
  TableCount = $ITABLES.count
  #SnapShots = $SNAPS
} | Format-list

#--Confirmation from user
Write-host -NoNewline " This will update the specified tables to the InnoDB storage engine.
Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}

#--Convert sensitive tables to InnoDB


foreach ($TABLE in $ITABLES)
    {
        $CHECK_TABLE = Invoke-SqlQuery -Query "select * from information_schema.tables where table_name = '$TABLE' and table_schema = 'mobiledoc_$m_SID'"
        if (!$CHECK_TABLE)
            {
                Write-Host "Table $TABLE does not exist. Exiting";exit
            }
        if ($CHECK_TABLE.engine -ne 'InnoDB')
            {
                Write-Host -NoNewline "Converting $TABLE to Innodb... "
                Invoke-SqlUpdate -Query "ALTER TABLE $TABLE ENGINE=InnoDB;"
                $CHECK_TABLE2 = Invoke-SqlQuery -Query "select * from information_schema.tables where table_name = '$TABLE' and table_schema = 'mobiledoc_$m_SID'"
                if ($CHECK_TABLE2.engine -eq 'InnoDB')
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
                else
                    {
                        Write-Host "Table $TABLE is already on InnoDB"
                    }
    }
Close-SqlConnection