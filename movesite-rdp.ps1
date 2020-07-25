#--Installs Client on specified TS Cluster

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}#;If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
            if ($ARG -eq '--help' -or $ARG -eq '-h' ){$HELP = $TRUE}
            if ($ARG -eq '--update-control'){$UPDATE_CONTROL = $TRUE}
            #if ($ARG -eq '--force' -or $ARG -eq '-f' ){$FORCE = $TRUE}
            if ($L -eq '--cluster' ){$CLUSTER = $R}
            if ($L -eq '--proceed' -or $L -eq '-y' ){$PROCEED = $TRUE}
    }

#--Display available options
if ($HELP -or !$SID)
    {
        [PSCustomObject] @{
        'Description' = 'Installs Client on specified RDP Cluster'
        '-h|--help' = 'display available options'
        '-s|--site' = 'Specify site ID'
        '--cluster' = 'Specify RDP Cluster'
        '--update-control' = 'Update control data with new RDP cluster ID. Not included by default for staging purposes'
        '-y|--proceed' = 'Proceed without confirmation'
        #'-f|--force' = 'Reinstall service locally'
                          }|Format-List;exit
    }

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site$SID`_DbUser"
$DSNUSER = "site$SID"
$DSNPWD = $SHOW.dsn_pwd
$DBPWD = $SHOW.dbuser_pwd
$APUID = $SHOW.apu_id
$DBPORT = "5$SID"
$SRC_TS_ID = $SHOW.ts_cluster_id
$SRC_TS1 = (invoke-mysql --site=000 --query="select t1 from ts_clusters where id = $SRC_TS_ID;").t1
$SRC_TS2 = (invoke-mysql --site=000 --query="select t2 from ts_clusters where id = $SRC_TS_ID;").t2
$SRC_SITE_ROOT = (invoke-mysql --site=000 --query="select site_root from ts_properties where name = '$SRC_TS1';").site_root
$SRC_SITE_ROOT_UNC = $SRC_SITE_ROOT.split(':')[0] + '$'

#--Get the target cluster information
if ($CLUSTER -like 'rdp*')
    {
        $CLUSTER_ID = (invoke-mysql --site=000 --query="select id from ts_clusters where rdp_address like '$CLUSTER%';").id
        if ($CLUSTER_ID.count -gt 1)
            {
                Write-Output "Multiple clusters found, please narrow search";exit
            }
    }
if ($CLUSTER -like 'ts*')
    {
        $CLUSTER_ID = (invoke-mysql --site=000 --query="select id from ts_clusters where t1 = '$CLUSTER' or t2 = '$CLUSTER';").id
    }
if ($CLUSTER -eq [int])
    {
        $CLUSTER_ID = $CLUSTER
    }
$TS1 = (invoke-mysql --site=000 --query="select t1 from ts_clusters where id = $CLUSTER_ID;").t1
$TS2 = (invoke-mysql --site=000 --query="select t2 from ts_clusters where id = $CLUSTER_ID;").t2
$SRC_SITE_ROOT = (invoke-mysql --site=000 --query="select site_root from ts_properties where name = '$SRC_TS1';").site_root
$SRC_SITE_ROOT_UNC = $SRC_SITE_ROOT.split(':')[0] + '$'
$SITE_ROOT = (invoke-mysql --site=000 --query="select site_root from ts_properties where name = '$TS1';").site_root
$SITE_ROOT_UNC = $SITE_ROOT.split(':')[0] + '$'
$TS_ARRAY = @()
$TS_ARRAY += $TS1
$TS_ARRAY += $TS2
$size = (gci \\$SRC_TS1\$SRC_SITE_ROOT_UNC\sites\$SID -Recurse|measure length -sum).sum/1GB
$size = [math]::round($size,2)

[PSCustomObject] @{
  Site = $SID
  "Source Cluster"= $SRC_TS1
  "Source site_root" = $SRC_SITE_ROOT,$SRC_SITE_ROOT_UNC
  "Dest Cluster"= $CLUSTER_ID,$TS1,$TS2
  "Dest site_root" = $SITE_ROOT,$SITE_ROOT_UNC
  "Current size" = "$size, \\$SRC_TS1\$SRC_SITE_ROOT_UNC\sites\$SID"
} | Format-list

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting copy/move..."}

#--Copy site folder from source to destination
Write-Host -NoNewline "Copying site folder from $SRC_TS1 to $TS1 "
robocopy /MIR /SEC /XO /FFT /NP /ETA /NFL /NDL /NJH /NJS /nc /ns \\$SRC_TS1\$SRC_SITE_ROOT_UNC\sites\$SID \\$TS1\$SITE_ROOT_UNC\sites\$SID|Out-Null
if (Test-Path "\\$TS1\$SITE_ROOT_UNC\sites\$SID\Program Files\eClinicalWorks\eClinicalworks.exe")
    {
        Write-Host -ForegroundColor Green "[OK]"
    }
        else
            {
                Write-Host -ForegroundColor Red "[FAIL]"
            }


#--Create the network share
Write-Host -NoNewline "Creating network share site$SID on $TS1 "
Invoke-Command -ComputerName $TS1 -ScriptBlock {New-SmbShare -name "site$using:SID" -Path "$using:SITE_ROOT`sites\$using:SID" -ChangeAccess "mycharts\site$using:SID`_group" -ErrorAction SilentlyContinue|Out-Null}
if (Test-Path \\$TS1\site$SID)
    {
        Write-Host -ForegroundColor Green "[OK]"
    }
        else
            {
                Write-Host -ForegroundColor Red "[FAIL]"
            }


#--Create ODBC entry
$DB = "mobiledoc_$SID"
$DRIVER = "M:\Program Files (x86)\MySQL\Connector ODBC 5.1\myodbc5.dll"
$UID = "site$SID"
foreach ($TS in $TS_ARRAY)
    {
        Invoke-Command -ComputerName $TS -ScriptBlock {
                New-Item -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI -Name "site$using:SID" -Force
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'DATABASE' -Value "$using:DB"
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'Driver' -Value "$using:DRIVER"
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'PORT' -Value "$using:DBPORT"
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'PWD' -Value "$using:DSNPWD"
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'SERVER' -Value "$using:DBCLUST"
                Set-ItemProperty -Path HKLM:\SOFTWARE\Wow6432Node\ODBC\ODBC.INI\site$using:SID -Name 'UID' -Value "$using:DSNUSER"
            }|Out-Null
    }

#--Update control_data
if ($UPDATE_CONTROL)
    {
        invoke-mysql --site=000 --query="update sitetab set ts_cluster_id = $CLUSTER_ID where siteid = $SID limit 1;"
    }