#--Zip and encrypt the MySQL Database, the ftp/mobiledoc folder, and the webapps/mobiledoc folder

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
#Import-Module $DRIVE\scripts\package_data.psm1
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
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = "$R"}
        if ($L -eq '--skipzipdb'){$SKIPDB = 'True'}
        if ($L -eq '--skipzipftp'){$SKIPFTP = 'True'}
        if ($L -eq '--skipzipwebapps'){$SKIPWEBAPPS = 'True'}
        if ($L -eq '--restart'){$m_RESTART = 'True'}
        if ($L -eq '--help' -or $L -eq '-h'){$HELP = 'True'}
        if ($L -eq '--upload'){$UPLOAD = 'True'}
        if ($L -eq '--archive'){$ARCHIVE = 'True'}
        if ($L -eq '--dirty'){$DIRTY = 'True'}
        if ($L -eq '--slave'){$USESLAVE = 'True'}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'--help or -h' = "Display this message"
'--site= or -s=' = "Specify the site number"
'--skipzipdb' = "Skip the count, export, and zipping of the Database"
'--skipzipftp' = "Skip the FTP data copy"
'--skipzipwebapps' = "Skip the Tomcat data copy"
'--restart' = "Restart all stopped services after all copy tasks have completed. NOTE: If both the database and tomcat copies are skipped, no services will be stopped"
'--upload' = "Upload exported files to public FTP"
'--archive' = "Copy zipped data to disengagement_non_response_archive"
'--dirty' = "Do not stop services to take the backup"
'--slave' = "Take DB backup from slave server"
                }|Format-List; exit
            }

#--Quit if no siteid specified
if (!$SID){Write-Output "Please specify a site ID using -s= or --site=, or use -h for the list of options";exit}
if ($SKIPDB -eq 'True' -and $SKIPFTP -eq 'True' -and $SKIPWEBAPPS -eq 'True'){Write-Output "Cannot skip all items";exit}

#--Generate Datestamp for naming zip files
$DATESTAMP = get-date -Format yyyy_MMdd

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCLID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCLID;"
$APP1 = $SHOW.a1

#--Get the DB info
if ($USESLAVE)
    {
        $SLVTEST = $SHOW.slave_server
        if (!$SLVTEST)# -notlike 'vmhost*' -or $SLVTEST -notlike 'dbclust*' -or $SLVTEST -notlike 'slave*')
            {
                Write-Host "DEBUG: $SLVTEST"
                write-host "--slave specified, but no slave server found";exit
                
            }
                else
                    {
                        $DBCLUST= $SHOW.slave_server
                    }
    }
        else
            {
                $DBCLUST = $SHOW.db_cluster
            }
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Get the eBO info
$EBOSRV = $SHOW.ebo_server

#--Get the APU number and server
$APU = $SHOW.apu_id
$APUAGENT = "ecwapuagent" + $APU
$APU06 = get-service -ComputerName apu06 -name $APUAGENT -ErrorAction SilentlyContinue
if ($APU06 -and $APU06.status -eq 'Running') 
    {$APUSRV = 'apu06';$APUSERVICE = get-service -ComputerName apu06 -name $APUAGENT}
        else 
            { if ($SID -gt 499) {$APUSRV = 'apu05';$APUSERVICE = get-service -ComputerName apu05 -name $APUAGENT}
                else
                    {$APUSRV = 'apu04';$APUSERVICE = get-service -ComputerName apu04 -name $APUAGENT}
    }

#--Get the m_INTERFACE info
$INT_SRV = $SHOW.a3
#Write-Host "DEBUG: Interface_Server = $INT_SRV"
if ($INT_SRV -like 'lab*'){$m_INTERFACE = '--INTERFACE'}

#--find the mysql directory
if (!$SKIPDB)
        {
         Write-host -NoNewLine "Searching for MySQL directory..."
         if ($DBCLUST -like 'dbclust*' -or 'virtdb*')
            {
                $HAMYSQL = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "for s in /ha*;do find `$s -maxdepth 2 -name site$SID;done"
            }
                else
                    {
                        $HAMYSQL = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "for s in /slave*;do find `$s -maxdepth 2 -name site$SID;done"
                    }
         If ($HAMYSQL){Write-Host "Found"}
         #Write-Output $HAMYSQL
        }

#--find the FTP directory
if (!$SKIPFTP)
        {
            Write-host -NoNewline "Searching for FTP directory..."
            $FTPSITES = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09a "/scripts/ffs -s=$SID"
            #$FTPSITES = $SHOW.ftp_cluster_folder + "/site$SID"
            #plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "for s in /sites*;do find `$s -maxdepth 2 -name site$SID;done"
            If ($FTPSITES){Write-Host "Found"}
            #Write-Output $FTPSITES
        }

#--Check for extraneous RAWFiles symlink
if (!$SKIPFTP)
        {
        $RAWF = 'True'
        #$RAWFILES = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09a "cd $FTPSITES/mobiledoc/ClearingHouseReports/ERA/RAWFiles/;ls -alt|grep -i rawf"
        #if ($RAWFILES){$RAWF = 'True'}
        }

#--Get the folder sizes for each item to be zipped
if (!$SKIPDB)
        {
            $DBSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "du -hs $HAMYSQL/mysql/data/mobiledoc_$SID"
        }
if (!$SKIPWEBAPPS)
        {
            if (Test-Path \\$APP1\site$SID\tomcat8) { $m_APPTOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$SID\tomcat7) { $m_APPTOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP1\site$SID\tomcat6) { $m_APPTOMCATDIR = 'tomcat6' }
                        }
                }
            $APPSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "du -hs /alley/site$SID/$m_APPTOMCATDIR/webapps/mobiledoc"
        }
if (!$SKIPFTP)
        {
            $FTPSIZE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "du -hs $FTPSITES/mobiledoc"
        }


[PSCustomObject] @{
  Tech     = $TECH1, $TECH 
  Site     = $SID
  Appserver= $APPSIZE, $APP1 
  Database = $DBSIZE, $DBCLUST, $HAMYSQL 
  FTPFolder= $FTPSIZE, $FTPSITES
  DbUser   = $DBUSER
  DB_PWD   = $DBPWD
  EBO      = $EBOSRV
  INTERFACE = $INT_SRV
  APU_ID   = $APU
  APUServer= $APUSRV
  RAWFiles = $RAWF
  SKIP_DB  = $SKIPDB
  SKIP_FTP = $SKIPFTP
  SKIP_APP = $SKIPWEBAPPS
  Do_Not_Stop = $DIRTY
  Restart  = $m_RESTART
  Upload   = $UPLOAD
  Archive  = $ARCHIVE
} | Format-list

#--Confirmation from user
Write-host -NoNewline "Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}

#--Get date/time stamp of start
$DATESTAMP1 = Get-Date -Format yyyy-MM-dd-hh:mm:ss

#--Email the tech re:start
Send-MailMessage -To "$TECH <$TECH>" -From "data_export@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "Data Copy for site$SID started at $DATESTAMP1" -Body ([PSCustomObject] @{
  Site     = $SID
  Appserver= $APPSIZE
  Database = $DBSIZE
  FTPFolder= $FTPSIZE
  DbUser   = $DBUSER
  EBO      = $EBOSRV
  INTERFACE = $INT_SRV
  APU_ID   = $APU
  APUServer= $APUSRV
  RAWFiles = $RAWF
  SKIP_DB  = $SKIPDB
  SKIP_FTP = $SKIPFTP
  SKIP_APP = $SKIPWEBAPPS
  Do_Not_Stop = $DIRTY
  Restart  = $m_RESTART
  Upload   = $UPLOAD
} | Format-list|Out-String)

#--shut down all the things
if (!$USESLAVE)
    {
        if (!$DIRTY)
            {
                if (!$SKIPWEBAPPS -and !$SKIPDB) 
                    {
                        #Write-Output "DEBUG: safe_tomcat --site=$SID --stop --clear --fast --force --both $m_INTERFACE"
                        safe_tomcat --site=$SID --stop --clear --fast --force --a $m_INTERFACE
                        safe_tomcat --site=$SID --stop --clear --fast --force --b
                        Write-host "Stopping APU Service on $APUSRV"
                        Stop-Service $APUSERVICE |Out-null
                        if ($EBOSRV)
                                {
                                    Write-Host "Stopping eBO Service on $EBOSRV"
                                    ebomgr --site=$SID --stop
                                    #plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBOSRV "/scripts/ebomgr --site=$SID --stop"
                                }
                    }
            }
    }


#--Sync primary ftp to secondary
if (!$SKIPFTP)
    {
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd $FTPSITES;rsync -avh store09a:`$PWD/mobiledoc ."
    }

#--Delete extraneous RAWFiles symlink
if (!$RAWF -and !$SKIPFTP)
        {Write-Output "RAWFiles symlink not present"} 
            else 
                {Write-Output "RAWFiles Symlink found, deleting"
                 plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd $FTPSITES/mobiledoc/ClearingHouseReports/ERA/RAWFiles/;rm -rf RAWFiles"               
        }


<#
$DBJOB =  'plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd $HAMYSQL/mysql/data/; mysqlshow --host=$DBCLUST -P5$SID -u$DBUSER -p$DBPWD mobiledoc_$SID > site$SID`_rowcount.txt; mysqldump --host=$DBCLUST -P5$SID -u$DBUSER -p$DBPWD mobiledoc_$SID > mobiledoc_$SID.sql;7za a -p$DBPWD -tzip -mem=AES256 -mx=4 mobiledoc_$SID`db_$DATESTAMP.zip mobiledoc_$SID.sql"'
$FTPJOB = 'plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd $FTPSITES; 7za a -p$DBPWD -tzip -mem=AES256  -l -mx=9 mobiledoc_$SID`ftp_$DATESTAMP.zip mobiledoc"'
$APPJOB = 'plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/tomcat6/webapps;7za a -p$DBPWD -tzip -mem=AES256 -mx=9 mobiledoc_$SID`app_$DATESTAMP.zip mobiledoc"'
#>


#--Get MySQL Rowcount, Dump MySQL database, ZIP dumped database
if (!$SKIPDB)
        {
        Start-Job -Name DBJob$SID -ScriptBlock ([scriptblock]::Create("package_data.ps1 --dbclust=$DBCLUST -s=$SID --dbuser=$DBUSER --hamysql=$HAMYSQL --pwd=$DBPWD --date=$DATESTAMP"))
        }
            else
                {Write-Host "DB Copy Skipped, moving on to Webapps operation..."}

                        
#--Zip the webapps/mobiledoc directory
if (!$SKIPWEBAPPS)

        {

            #Write-host -NoNewline "Zipping Webapps/Mobiledoc..."
            Start-Job -Name WebappsJob$SID -ScriptBlock ([scriptblock]::Create("package_data.ps1 --app=$APP1 -s=$SID --pwd=$DBPWD --date=$DATESTAMP"))
            #Write-host "Done"
        }

#--Zip the ftp/mobiledoc directory

if (!$SKIPFTP)
    {
        #Write-Host -NoNewline "Zipping ftp/mobiledoc directory..."
        Start-Job -Name FTPJob$SID -ScriptBlock ([scriptblock]::Create("package_data.ps1 --ftp=$FTPSITES -s=$SID --pwd=$DBPWD --date=$DATESTAMP"))
        #Write-host "Done"

    }
        else
            {Write-Host "FTP Copy Skipped" }


#--Wait for the jobs to complete
get-job|wait-job

#--Get the file sizes of the zips you created
if (!$SKIPDB)
    {$DBZIP = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "du -hs /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID`_db_$DATESTAMP.zip"}
if (!$SKIPWEBAPPS)
    {$WEBAPPSZIP = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "du -hs /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID`_app_$DATESTAMP.zip"}
if (!$SKIPFTP)
    {$FTPZIP = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "du -hs /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID`_ftp_$DATESTAMP.zip"}


<#--Copy the zip files to store09c
if (!$SKIPDB)
    {
     plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd $HAMYSQL/mysql/data; scp mobiledoc_$SID`_db_$DATESTAMP.zip store09c:/storage13/tmp_staging/data_export/site$SID/"
     plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd $HAMYSQL/mysql/data; scp site$SID`_rowcount.txt store09c:/storage13/tmp_staging/data_export/site$SID/"
    }
if (!$SKIPWEBAPPS)
    {plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$m_APPTOMCATDIR/webapps; scp mobiledoc_$SID`_app_$DATESTAMP.zip store09c:/storage13/tmp_staging/data_export/site$SID/"}
#if (!$SKIPFTP)
    {$FTPZIP = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "du -hs /storage13/tmp_staging/mobiledoc_$SID`_ftp_$DATESTAMP.zip"}
#>

#--Check the SQL dump to make sure it completed successfully
$DBSQLTEST = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "tail /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID.sql"
if ($DBSQLTEST[-1] -like "*Dump completed*")
    {
        $DOTSQLTEST = "[SUCCESS]"
    }
        else
            {
                $DOTSQLTEST = "[ERROR]"
            }

[PSCustomObject] @{
  Orig_DB_Size = $DBSIZE
  Orig_APP_Size= $APPSIZE
  Orig_FTP_Size= $FTPSIZE
Zipped_DB = $DOTSQLTEST, $DBZIP
Zipped_Webapps = $WEBAPPSZIP
Zipped_FTP = $FTPZIP
} | Format-list

#--Clear completed jobs
get-job -State Completed|Remove-Job

#--Restart all the things
if ($m_RESTART)
    {
        safe_tomcat --site=$SID --start --both $m_INTERFACE
        Write-host "Starting APU Service on $APUSRV"
        Start-Service $APUSERVICE|Out-null
        <#if ($EBOSRV)
                {Write-Host "Starting eBO Service on $EBOSRV"
                 plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBOSRV "/scripts/ebomgr --site=$SID --start"}#>
    }

#--Upload files
if ($UPLOAD -eq 'True')
    {#--Create directory on FTP
    write-host "DEBUG: $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt"
        Write-Output "Creating site$SID folder on oldftp.psmnv.com"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com; mkdir /site$SID;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
        if ($DBZIP)
            {Write-host -NoNewline "Uploading rowcount and database zip..."
            #plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "cd $HAMYSQL/mysql/data/;lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com;cd /site$SID;put site$SID`_rowcount.txt;put mobiledoc_$SID`_db_$DATESTAMP.zip;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/;lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com;cd /site$SID;put site$SID`_rowcount.txt;put mobiledoc_$SID`_db_$DATESTAMP.zip;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
            Write-Host "Done"}
        if ($WEBAPPSZIP)
            {Write-host -NoNewline "Uploading Webapps zip..."
            #plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$m_APPTOMCATDIR/webapps/;lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com;cd /site$SID;put mobiledoc_$SID`_app_$DATESTAMP.zip;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/;lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com;cd /site$SID;put mobiledoc_$SID`_app_$DATESTAMP.zip;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
            Write-Host "Done"}
        if ($FTPZIP)
            {Write-host -NoNewline "Uploading FTP zip..."
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/;lftp -c 'open -u ftpguest.psmnv.com,iH34rtPSM! oldftp.psmnv.com;cd /site$SID;put mobiledoc_$SID`_ftp_$DATESTAMP.zip;bye'"|Tee-Object -FilePath $DRIVE`scripts\logs\data_copy\site$SID`_upload.txt -Append
            Write-Host "Done"}
    }

#--If --archive is specified, move all zipped files to store09c:/storage13/disengagement_non_response_archive/site$SID/
if ($ARCHIVE)
    {
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/disengagement_non_response_archive/;mkdir site$SID"
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/;mv * /storage13/disengagement_non_response_archive/site$SID/"
    }

#--Get date/time stamp of end
$DATESTAMP2 = Get-Date -Format yyyy-MM-dd-hh:mm:ss

#--Email the tech re:end
Send-MailMessage -To "$TECH <$TECH>" -From "data_export@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "Data Copy for site$SID completed $DATESTAMP2" -Body ([PSCustomObject] @{
  Orig_DB_Size = $DBSIZE
  Orig_APP_Size= $APPSIZE
  Orig_FTP_Size= $FTPSIZE
Zipped_DB = $DOTSQLTEST, $DBZIP
Zipped_Webapps = $WEBAPPSZIP
Zipped_FTP = $FTPZIP
} | Format-list|Out-String)
    