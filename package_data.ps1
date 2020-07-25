#--Function called by data_export.ps1 to perform the database sql dump and file zip/encrypt jobs

$DRIVE = (Get-Location).Drive.Root

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
        if ($L -eq '--ftp'){$FTPSITES = $R}
        if ($L -eq '--pwd'){$DBPWD = $R}
        if ($L -eq '--date'){$DATESTAMP = $R}
        if ($L -eq '--dbclust'){$DBCLUST = $R}
        if ($L -eq '--dbuser'){$DBUSER = $R}
        if ($L -eq '--hamysql'){$HAMYSQL = $R}
        if ($L -eq '--app'){$APP1 = $R}
    }


#--Create staging folder on store09c
plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export;mkdir site$SID"

#--Zip the FTP Data
if ($FTPSITES)
    {
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd $FTPSITES; 7za a -p$DBPWD -tzip -mem=AES256  -l -mx=7 /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID`_ftp_$DATESTAMP.zip mobiledoc"|Tee-Object -FilePath $DRIVE\scripts\logs\data_copy\site$SID`_FTP.txt
    }

#--Zip the Webapps/mobiledoc data
if ($APP1)
    {
        if (Test-Path \\$APP1\site$SID\tomcat8) { $APPTOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$SID\tomcat7) { $APPTOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP1\site$SID\tomcat6) { $APPTOMCATDIR = 'tomcat6' }
                        }
                }
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$APPTOMCATDIR/webapps;7za a -p$DBPWD -tzip -mem=AES256 -mx=7 mobiledoc_$SID`_app_$DATESTAMP.zip mobiledoc"|Tee-Object -FilePath $DRIVE\scripts\logs\data_copy\site$SID`_APP.txt
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/; rsync -avh $APP1`:/alley/site$SID/$APPTOMCATDIR/webapps/mobiledoc_$SID`_app_$DATESTAMP.zip ."
        $APPZIP1 = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "ls -l /alley/site$SID/$APPTOMCATDIR/webapps/mobiledoc_$SID`_app_$DATESTAMP.zip"
        $APPZIP2 = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "ls -l /storage13/tmp_staging/data_export/site$SID/mobiledoc_$SID`_app_$DATESTAMP.zip"

        #--Cleanup the zip file from the application server
            If ($APPZIP1.split(' ')[4] -eq $APPZIP2.split(' ')[4])
                {
                    plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$APPTOMCATDIR/webapps/;rm -f mobiledoc_$SID`_app_$DATESTAMP.zip"
                }
    }

#--Get MySQL Rowcount, Dump MySQL database, ZIP dumped database
if ($DBCLUST)
    {
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/; mysqlshow --host=$DBCLUST -P5$SID -u$DBUSER -p$DBPWD mobiledoc_$SID --count > site$SID`_rowcount.txt;"
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/; mysqldump --host=$DBCLUST -P5$SID -u$DBUSER -p$DBPWD --compatible=no_table_options --single-transaction mobiledoc_$SID > mobiledoc_$SID.sql"|Tee-Object -FilePath $DRIVE\scripts\logs\data_copy\site$SID`_DB.txt
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09c "cd /storage13/tmp_staging/data_export/site$SID/; 7za a -p$DBPWD -tzip -mem=AES256 -mx=4 mobiledoc_$SID`_db_$DATESTAMP.zip mobiledoc_$SID.sql"|Tee-Object -FilePath $DRIVE\scripts\logs\data_copy\site$SID`_DB.txt -Append

    }