#--Move FTP instance from one /sites folder to another

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
            if ($L -eq '--to' -or $L -eq '-t') {$T_FOLD = $R}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}

    }

#--make sure a site ID & destination folder are specified
if (!$m_SID -or !$T_FOLD)
    {
        $HELP = $TRUE
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Moves apps from current FTP folder to specified FTP folder'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--to|-t' = 'Specify the destination FTP folder'
                }|Format-List; exit
            }

#--Get the site information from ControlData
$SHOW = Show-Site --site=$m_SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $m_SID;"
$FTPPWD = $SHOW.dsn_pwd

#--get the current folder, both from sitetab and the FTP, make sure they match
$TEST_FOLDER1 = $SHOW.ftp_folder
$TEST_FOLDER2 = "/" + (Connect-Ssh -ComputerName virtftp -ScriptBlock  "ffs --site=$m_SID").split('/')[1]
if ($TEST_FOLDER1 -ne $TEST_FOLDER2)
    {
        Write-Host "FTP folder does not match control data entry. Please check and correct discrepency, then run script again"
        exit
    }
        else
        {
            $F_FOLD = $TEST_FOLDER1
        }

#--get the current FTP size
$FTP_SIZE = Connect-Ssh -ComputerName virtftp -ScriptBlock  "du -hs $F_FOLD/site$m_SID"

#--get the current destination disk capacity, ensure it has more than enough space on A, B, & C servers
$T_TEST = Connect-Ssh -ComputerName virtftp -ScriptBlock  "df -h|grep $T_FOLD"
$T_USED = (($T_TEST).split(' ')[-2]).trimend('%')
if ((($T_TEST).split(' ')[-2]).trimend('%') -ge 70)
    {
        Write-Host "$T_FOLD is at or above 70% full. Please choose a different destination folder with more space"
        exit
    }

#--confirm move
echo ""
echo "#####################################################"
echo "##                                                 ##"
echo "##            Move FTP Folder Instance             ##"
echo "##                                                 ##"
echo "#####################################################"
echo ""
echo "       site: $m_SID"
echo "       size: $FTP_SIZE"
echo "       from: $F_FOLD"
echo "         to: $T_FOLD, $T_USED% used"

echo ""
#--Confirmation from user
Write-host -NoNewline "move FTP Folder Instance for site$m_SID`?

Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}

#--1st rsync $F_FOLD/site$m_SID to $T_FOLD/ on 'A' FTP server
Write-Host "First Rsync pass..."
Start-Job -Name site$m_SID`_FTP_B1 -ScriptBlock {Connect-Ssh -ComputerName store09b -ScriptBlock  "rsync -avh $using:F_FOLD/site$using:m_SID $using:T_FOLD/"}|Out-Null
Start-Job -Name site$m_SID`_FTP_C1 -ScriptBlock {Connect-Ssh -ComputerName store09c -ScriptBlock  "mv $using:F_FOLD/site$using:m_SID $using:T_FOLD/"}|Out-Null
Connect-Ssh -ComputerName store09a -ScriptBlock  "rsync -avhq $F_FOLD/site$m_SID $T_FOLD/"
Get-Job -Name site$m_SID`_FTP_B1|Wait-Job
#Write-Host "Done"

#--backup the pureftp files, update them, and commit changes
Write-Host -NoNewline "Backing up PureFTP files..."
$DATESTAMP = (Get-Date -Format yyyyMMdd-hhmmss)
Connect-Ssh -ComputerName store09a -ScriptBlock  "cd /_ftpauth/;cp pureftpd.passwd backups/pureftpd.passwd.$DATESTAMP;cp pureftpd.pdb backups/pureftpd.pdb.$DATESTAMP"
$TEST_PURE_BACKUP = Connect-Ssh -ComputerName store09a -ScriptBlock  "du -hs /_ftpauth/backups/*.$DATESTAMP"
Connect-Ssh -ComputerName store09b -ScriptBlock  "cd /_ftpauth/;cp pureftpd.passwd backups/pureftpd.passwd.$DATESTAMP;cp pureftpd.pdb backups/pureftpd.pdb.$DATESTAMP"
$TEST_PURE_BACKUP_B = Connect-Ssh -ComputerName store09b -ScriptBlock  "du -hs /_ftpauth/backups/*.$DATESTAMP"
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
        #else
         #   {
          #      Write-Host "Done"
           # }

Write-Host -NoNewline "Updating pureftpd.passwd"
Connect-Ssh -ComputerName store09a -ScriptBlock  "pure-pw usermod site$m_SID -f /_ftpauth/pureftpd.passwd -D $T_FOLD/site$m_SID"
Connect-Ssh -ComputerName store09b -ScriptBlock  "pure-pw usermod site$m_SID -f /_ftpauth/pureftpd.passwd -D $T_FOLD/site$m_SID"
#Connect-Ssh -ComputerName store09a -ScriptBlock  "cd /_ftpauth;sed -i 's/\$F_FOLD\/site$m_SID/\$T_FOLD\/site$m_SID/g' pureftp.passwd"
#Connect-Ssh -ComputerName store09b -ScriptBlock  "cd /_ftpauth;sed -i 's/\$F_FOLD\/site$m_SID/\$T_FOLD\/site$m_SID/g' pureftp.passwd"
if (-not (Connect-Ssh -ComputerName store09a -ScriptBlock  "cat /_ftpauth/pureftpd.passwd|grep '$T_FOLD/site$m_SID'"))
    {
        write-host -ForegroundColor Red "[FAILED]"
        Write-Host "Did not update pureftpd.passwd successfully. Exiting"
        exit
    }
        else
            {
                Write-Host "Done"
            }

Write-Host "Committing FTP changes"
Connect-Ssh -ComputerName store09a -ScriptBlock  "ftpcommit"
Connect-Ssh -ComputerName store09b -ScriptBlock  "ftpcommit"

#--2nd rsync $F_FOLD/site$m_SID to $T_FOLD/ on 'A' FTP server
Write-Host -NoNewline "Second Rsync pass..."
Start-Job -Name site$m_SID`_FTP_B2 -ScriptBlock {Connect-Ssh -ComputerName store09b -ScriptBlock  "rsync -avh $using:F_FOLD/site$using:m_SID $using:T_FOLD/"}
Connect-Ssh -ComputerName store09a -ScriptBlock  "rsync -avhq $F_FOLD/site$m_SID $T_FOLD/"
Get-Job -Name site$m_SID`_FTP_B2|Wait-Job
Write-Host "Done"

#--test the FTP for specified site
Connect-Ssh -ComputerName store01 -ScriptBlock  "cd /scripts/sources/;echo '$T_FOLD/site$m_SID' > store09a_$DATESTAMP.txt;lftp -c 'open -u site$m_SID,$FTPPWD store09a;put store09a_$DATESTAMP.txt';rm -f store09a_$DATESTAMP.txt"
Connect-Ssh -ComputerName store01 -ScriptBlock  "cd /scripts/sources/;echo '$T_FOLD/site$m_SID' > store09b_$DATESTAMP.txt;lftp -c 'open -u site$m_SID,$FTPPWD store09b;put store09b_$DATESTAMP.txt';rm -f store09b_$DATESTAMP.txt"
Write-Host -NoNewline "Checking file upload on store09a..."
$TEST_A_UPLOAD = Connect-Ssh -ComputerName store09a -ScriptBlock  "du -hs $T_FOLD/site$m_SID/store09a_$DATESTAMP.txt"
if (!$TEST_A_UPLOAD)
    {
        Write-Host -ForegroundColor Red '[FAIL]'
    }
        else
            {
                Write-Host -ForegroundColor Green '[OK]'
            }
Write-Host -NoNewline "Checking file upload on store09b..."
$TEST_B_UPLOAD = Connect-Ssh -ComputerName store09b -ScriptBlock  "du -hs $T_FOLD/site$m_SID/store09b_$DATESTAMP.txt"
if (!$TEST_B_UPLOAD)
    {
        Write-Host -ForegroundColor Red '[FAIL]'
    }
        else
            {
                Write-Host -ForegroundColor Green '[OK]'
            }


#--run fix_samba to update the network share path
Connect-Ssh -ComputerName store09a -ScriptBlock  "fix_samba"
Connect-Ssh -ComputerName store09b -ScriptBlock  "fix_samba"

#--run setftpperms
Connect-Ssh -ComputerName store09a -ScriptBlock  "setftpperms --site=$m_SID"
Connect-Ssh -ComputerName store09b -ScriptBlock  "setftpperms --site=$m_SID"

#--Verify that new site folder is equal or greater in size than source directory
Write-Host -NoNewline "Comparing file size of source and destination folders..."
#$TEST_SIZE_A1 = (((Connect-Ssh -ComputerName store09a -ScriptBlock  "du -s /sites02/site622").tostring()).split('/')[0]).trimend()
$TEST_SIZE_A1 = (((Connect-Ssh -ComputerName store09a -ScriptBlock  "du -s $F_FOLD/site$m_SID").tostring()).split('/')[0]).trimend()
#$TEST_SIZE_B1 = Connect-Ssh -ComputerName store09b -ScriptBlock  "du -s $F_FOLD/site$m_SID"
$TEST_SIZE_A2 = (((Connect-Ssh -ComputerName store09a -ScriptBlock  "du -s $T_FOLD/site$m_SID").tostring()).split('/')[0]).trimend()
#$TEST_SIZE_B2 = Connect-Ssh -ComputerName store09b -ScriptBlock  "du -s $T_FOLD/site$m_SID"
if ($TEST_SIZE_A2 -ge $TEST_SIZE_A1)
    {
        Write-Host -ForegroundColor Green '[OK]'
    }
        else
            {
                Write-Host -ForegroundColor Red '[FAIL]'
                Write-Host "Destination folder is smaller than source. Exiting"
                Exit
            }
    

#--remove the old ftp folder
Write-host -NoNewline "Remove the source folder at $F_FOLD/site$m_SID`?.

        Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
Connect-Ssh -ComputerName store09a -ScriptBlock  "cd $F_FOLD;rm -rf site$m_SID"
Connect-Ssh -ComputerName store09b -ScriptBlock  "cd $F_FOLD;rm -rf site$m_SID"
Invoke-MySQL -Site 000 -Update -Query "update sitetab set ftp_cluster_folder = '$T_FOLD' where siteid = $m_SID limit 1;"