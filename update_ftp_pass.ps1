#--Update FTP password for a specified site
#$NYI = $TRUE
#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
            if ($L -eq '--password' -or $L -eq '-p') {$PASSWORD = $R}
            if ($L -eq '--revert') {$REVERT = $TRUE}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}

    }

#--make sure a site ID & destination folder are specified
if (!$m_SID)
    {
        $HELP = $TRUE
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Updates the FTP password for the specified site'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--password|-p' = 'Specify a desired password. Defaults to creating a random password'
'--revert' = 'Revert to previous FTP password, as specified in the old_ftp_pwd field'
                }|Format-List; exit
            }

#--get site data from control database
$SHOW = Show-Site --site=$m_SID --tool
#$SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $m_SID and status like 'a%';"
if (!$SHOW)
    {
        Write-Host "site not found or is inactive. Exiting"
        exit
    }

if ($REVERT)
    {
        $OLD_PASS = $SHOW.ftp_pwd
    }
        else
            {
                if ($m_SID -le 132)
                    {
                        $OLD_PASS = "site$m_SID`_ecw"
                    }
                        else
                            {
                                $OLD_PASS = $SHOW.dsn_pwd
                            }
            }

#--Get the DB info
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site$m_SID`_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Create new random password
if (!$PASSWORD)
    {
        if ($REVERT)
            {
                $PASSWORD = $SHOW.old_ftp_pwd
            }
                else
                    {      
                        $PASSWORD = -join(1..8 | ForEach {((65..90)+(97..122) | % {[char]$_})+(0..9) | Get-Random})
                    }
    }

#--Find the FTP folder for testing
$FFS = "/" + (plink -i \scripts\sources\ts01_privkey.ppk root@virtftp "ffs --site=$m_SID").split('/')[1]


[PSCustomObject] @{
'siteid' = "$m_SID"
'old pass' = "$OLD_PASS"
'new pass' = "$PASSWORD"

        }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Updating ftp password"}

#--backup the pureftp files, update them, and commit changes
Write-Host -NoNewline "Backing up PureFTP files..."
$DATESTAMP = (Get-Date -Format yyyyMMdd-hhmmss)
plink -i \scripts\sources\ts01_privkey.ppk root@store09a "cd /_ftpauth/;cp pureftpd.passwd backups/updates/pureftpd.passwd.$DATESTAMP`_$m_SID;cp pureftpd.pdb backups/updates/pureftpd.pdb.$DATESTAMP`_$m_SID"
$TEST_PURE_BACKUP = plink -i \scripts\sources\ts01_privkey.ppk root@store09a "du -hs /_ftpauth/backups/updates/*.$DATESTAMP`_$m_SID"
plink -i \scripts\sources\ts01_privkey.ppk root@store09b "cd /_ftpauth/;cp pureftpd.passwd backups/updates/pureftpd.passwd.$DATESTAMP`_$m_SID;cp pureftpd.pdb backups/updates/pureftpd.pdb.$DATESTAMP`_$m_SID"
$TEST_PURE_BACKUP_B = plink -i \scripts\sources\ts01_privkey.ppk root@store09b "du -hs /_ftpauth/backups/updates/*.$DATESTAMP`_$m_SID"
if ($TEST_PURE_BACKUP.count -lt 2)
    {
        Write-host -NoNewline "PureFTP configuration files not backed up successfully on store09a. Please manually back up these files.

        Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {
                Write-Host "Done"
            }
if ($TEST_PURE_BACKUP_B.count -lt 2)
    {
        Write-host -NoNewline "PureFTP configuration files not backed up successfully on store09b. Please manually back up these files.

        Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }

#--update the password on the ftp servers
if (!$NYI)
    {
        Write-Host "Updating FTP password for site$m_SID on store09a..."
        plink -i \scripts\sources\ts01_privkey.ppk root@store09a "( echo $PASSWORD ; echo $PASSWORD ) |pure-pw passwd site$m_SID -f /_ftpauth/pureftpd.passwd"
        Write-Host "Updating FTP password for site$m_SID on store09b..."
        plink -i \scripts\sources\ts01_privkey.ppk root@store09b "( echo $PASSWORD ; echo $PASSWORD ) |pure-pw passwd site$m_SID -f /_ftpauth/pureftpd.passwd"
        plink -i \scripts\sources\ts01_privkey.ppk root@store09a "ftpcommit"
        plink -i \scripts\sources\ts01_privkey.ppk root@store09b "ftpcommit"
    }

#--test the FTP for specified site
plink -i \scripts\sources\ts01_privkey.ppk root@store01 "cd /scripts/sources/;echo 'store09a_$DATESTAMP' > store09a_$DATESTAMP.txt;lftp -c 'open -u site$m_SID,$PASSWORD store09a;put store09a_$DATESTAMP.txt';rm -f store09a_$DATESTAMP.txt"
plink -i \scripts\sources\ts01_privkey.ppk root@store01 "cd /scripts/sources/;echo 'store09b_$DATESTAMP' > store09b_$DATESTAMP.txt;lftp -c 'open -u site$m_SID,$PASSWORD store09b;put store09b_$DATESTAMP.txt';rm -f store09b_$DATESTAMP.txt"
Write-Host -NoNewline "Checking file upload on store09a..."
$TEST_A_UPLOAD = plink -i \scripts\sources\ts01_privkey.ppk root@store09a "du -hs $FFS/site$m_SID/store09a_$DATESTAMP.txt"
if (!$TEST_A_UPLOAD)
    {
        Write-Host -ForegroundColor Red '[FAIL]'
    }
        else
            {
                Write-Host -ForegroundColor Green '[OK]'
            }
Write-Host -NoNewline "Checking file upload on store09b..."
$TEST_B_UPLOAD = plink -i \scripts\sources\ts01_privkey.ppk root@store09b "du -hs $FFS/site$m_SID/store09b_$DATESTAMP.txt"
if (!$TEST_B_UPLOAD)
    {
        Write-Host -ForegroundColor Red '[FAIL]'
    }
        else
            {
                Write-Host -ForegroundColor Green '[OK]'
            }

#--If both FTP upload tests fail, bail out
if (!$TEST_A_UPLOAD -and !$TEST_B_UPLOAD)
    {
        Write-Host "Both FTP Upload tests failed. Please fix the Pure-FTP password for site$m_SID"
        exit
    }

#--update the password in control data
if ($TEST_A_UPLOAD -and $TEST_B_UPLOAD)
    {
        if (!$NYI)
            {
                Write-Host "Updating control data"
                Invoke-MySQL -Site 000 -Query "update sitetab set ftp_pwd = '$PASSWORD' where siteid = $m_SID limit 1;"
                Invoke-MySQL -Site 000 -Query "update sitetab set old_ftp_pwd = '$OLD_PASS' where siteid = $m_SID limit 1;"
            }
    }

#--update the password in ftpconfig, ftp_params, & ftp_params_era
if ($TEST_A_UPLOAD -and $TEST_B_UPLOAD)
    {
        if (!$NYI)
            {
                Write-Host -NoNewline "Updating ftpconfg"
                Invoke-MySQL -Site $m_SID -Query "update ftpconfig set defaultpassword = '$PASSWORD' where defaultusername = 'site$m_SID' limit 1;"
                if ((Invoke-MySQL -Site $m_SID -Query "select defaultpassword from ftpconfig where defaultusername = 'site$m_SID'").defaultpassword -eq $PASSWORD)
                    {
                        Write-Host -ForegroundColor Green '[OK]'
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red '[FAIL]'
                            }
                Write-Host -NoNewline "Updating ftp_params"
                Invoke-MySQL -Site $m_SID -Query "update ftp_params set ftppassword = '$PASSWORD' where ftpuserid = 'site$m_SID' limit 1;"
                if ((Invoke-MySQL -Site $m_SID -Query "select ftppassword from ftp_params where ftpuserid = 'site$m_SID'").ftppassword -eq $PASSWORD)
                    {
                        Write-Host -ForegroundColor Green '[OK]'
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red '[FAIL]'
                            }
                Write-Host -NoNewline "Updating ftp_params_era"
                Invoke-MySQL -Site $m_SID -Query "update ftp_params_era set ftppassword = '$PASSWORD' where ftpuserid = 'site$m_SID' limit 1;"
                if ((Invoke-MySQL -Site $m_SID -Query "select ftppassword from ftp_params_era where ftpuserid = 'site$m_SID'").ftppassword -eq $PASSWORD)
                    {
                        Write-Host -ForegroundColor Green '[OK]'
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red '[FAIL]'
                            }
            }
    }