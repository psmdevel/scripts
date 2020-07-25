#--Enable UseHttpInstdOfFtpVb itemkey

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
        if ($L -eq '-y' -or $L -eq '--proceed') {$PROCEED = $TRUE}
    }

#--Display available options
if ($HELP -or !$SID)
    {
        [PSCustomObject] @{
        'Description' = 'Enable UseHttpInstdOfFtpVb itemkey'
        '-h|--help' = 'display available options'
        '-s|--site' = 'Specify site ID'
        '-y|--proceed' = 'Proceed without confirmation'
        #'-f|--force' = 'Reinstall service locally'
                          }|Format-List;exit
    }



#--Get the site info from database
$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--get the ftp port number from the ftpconfig table and ensure that the ftp_params table matches
$FTPPORT = (Invoke-MySQL -Site $SID -Query "select * from ftpconfig;").port
$FTPPARAMSPORT = (Invoke-MySQL -Site $SID -Query "select * from ftp_params;").ftpportno
if ($FTPPARAMSPORT -ne $FTPPORT)
    {
        $UPDATEFTPPORT = $TRUE
    }
        else
            {
                $UPDATEFTPPORT = $FALSE
            }

#--Get related itemkeys
$USEHTTP = Invoke-MySQL -Site $SID -Query "select itemid,value from itemkeys where name = 'UseHttpInstdOfFtpVB';"
$EMRSRV = Invoke-MySQL -Site $SID -Query "select itemid,value from itemkeys where name in ('EMR_SrvHostName','EMR_SrvProtocol');"

[PSCustomObject] @{
  Site     = $SID
  Update_ftp_params_port   = $UPDATEFTPPORT
  UseHttpInstdOfFtpVB = $USEHTTP.itemid,$USEHTTP.value
  
} | Format-list

if ($UPDATEFTPPORT -eq $FALSE -and $USEHTTP.itemid -eq 1 -and $USEHTTP.value -eq 'yes')
    {
        Write-Host "No changes necessary. Exiting"
        exit
    }
#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enables UseHttpInstdOfFtpVb itemkey and ensures ftp_params port is set properly.
        
Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Enabling itemkey..."}

#--Confirmation from user
#Write-host -NoNewline "Enables UseHttpInstdOfFtpVb itemkey and ensures ftp_params port is set properly.

#Enter 'PROCEED' to continue: "
#$RESPONSE = read-host
#if ($RESPONSE -cne 'PROCEED') {exit}

#--Set the ftp_parms FtpPortNo
if ($UPDATEFTPPORT -eq $TRUE)
    {
        Invoke-MySQL -Site $SID -Update -Query "update ftp_params set ftpportno = $FTPPORT;"
    }

#--Update itemkeys
Invoke-MySQL -Site $SID -Update -Query "update itemkeys set itemid = 1, value = 'yes' where name = 'UseHttpInstdOfFtpVB' limit 1;"