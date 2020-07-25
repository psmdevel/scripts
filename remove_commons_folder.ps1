#--Script created in response to GroupOne ticket to eCW in regards to the new ICD10 import utility not working on SP1C-20.8. The fix is to remove the mobiledoc/WEB-INF/classes/org/apache/commons folder and restart tomcat.

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        if ($ARG -like '*:*' -and $ARG -notlike '*:\*'){Write-Output 'Please use "=" to specify arguments'; exit}
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--list'){$LIST = $R}
    }

if ($m_SID)
    {$SITEARRAY = @()
     $SITEARRAY += $m_SID}
     else
        {
    if ($LIST)
        {
            $SITEARRAY = get-content $LIST #|ForEach-Object {$_.ToString("000")}
        }
    }

#--Debug sitelist
$COUNT = $SITEARRAY.Count
write-host "DEBUG: List $SITEARRAY"
Write-Host "DEBUG: Count $COUNT"


foreach ($SID in $SITEARRAY) 
    {

        #--Get the site information from ControlData
        $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"


        #--Get the tomcat servers
            $APPCID = $SHOW.app_cluster_id[0]
            $APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
            $APP1 = $APPID.a1
            $APP2 = $APPID.a2

        #--Get the tomcat version
        if (Test-Path \\$APP1\site$SID\tomcat8) { $APPTOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$SID\tomcat7) { $APPTOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP1\site$SID\tomcat6) { $APPTOMCATDIR = 'tomcat6' }
                        }
                }
    }
        #--Test existence of common folder
        $TESTFOLDER1 = Test-Path -Path \\$APP1\site$SID\$APPTOMCATDIR\webapps\mobiledoc\WEB-INF\classes\org\apache\commons
        $TESTFOLDER2 = Test-Path -Path \\$APP2\site$SID\$APPTOMCATDIR\webapps\mobiledoc\WEB-INF\classes\org\apache\commons

    #--Tomcat restart is required. Warn technician and prompt for confirmation

    if ($TESTFOLDER1 -eq $TRUE -or $TESTFOLDER2 -eq $TRUE)
        {
            Write-Host "Commons folder found. Tomcat restart is required for site$SID"
            Write-host -NoNewline "Enter 'PROCEED' to continue: "
            $RESPONSE = read-host
            if ($RESPONSE -cne 'PROCEED') {exit}

                if ($TESTFOLDER1 -eq $TRUE)
                    {
                        Write-Host "~: Commons folder exists for site$SID on $APP1"
                        Write-host "~: Stopping tomcat A"
                        safe_tomcat.ps1 --site=$SID --stop --clear --fast --a
                        setperms --site=$SID --unlock -a
                        Write-host -NoNewline "~: Removing commons folder..."
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$APPTOMCATDIR/webapps/mobiledoc/WEB-INF/classes/org/apache;rm -rf commons"
                        Write-host " Done."
                        setperms --site=$SID -a
                        safe_tomcat.ps1 --site=$SID --start -a
                    }
                        else
                            {Write-host "~: Commons folder not found for site$SID on $APP1"}

                if ($TESTFOLDER2 -eq $TRUE)
                    {
                        Write-Host "~: Commons folder exists for site$SID on $APP2"
                        Write-host "~: Stopping tomcat B"
                        safe_tomcat.ps1 --site=$SID --stop --clear --fast --b
                        setperms --site=$SID --unlock -b
                        Write-host -NoNewline "~: Removing commons folder..."
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$SID/$APPTOMCATDIR/webapps/mobiledoc/WEB-INF/classes/org/apache;rm -rf commons"
                        Write-host " Done."
                        setperms --site=$SID -b
                        safe_tomcat.ps1 --site=$SID --start -b
                    }
                        else
                            {Write-host "~: Commons folder not found for site$SID on $APP2"}
        }
        
