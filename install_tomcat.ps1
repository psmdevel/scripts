#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

#--Process the command-line arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
            if ($L -eq '--app'){$APP = $R}
            if ($L -eq '--timezone' -or $L -eq '-tz'){$TZ = $R}
            if ($L -eq '--min'){$MIN = $R}
            if ($L -eq '--max'){$MAX = $R}
            if ($L -eq '--version' -or $L -eq '-ver'){$TOMCATVER = $R}
            if ($ARG -eq '-h' -or $ARG -eq '--help'){$HELP = 'True'}
            IF ($L -eq '-y') {$PROCEED = 'TRUE'} else {$PROCEED = 'FALSE'}
            if ($ARG -eq '--migrate'){$MIGRATE = 'True'}
            if ($ARG -eq '--staged'){$STAGED = 'True'}
            if ($ARG -eq '--nostart'){$NOSTART = 'True'}
    }

#--Display available options
if ($HELP -eq 'True' -or !$ARGS)
{
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s|--site' = 'set site number'
    '-tz|--timezone' = 'set timezone'
    '-ver|--version' = 'set tomcat version'
    '--app' = 'set source application server'
    '--min' = 'set minimum tomcat memory'
    '--max' = 'set maximum tomcat memory'
    '--migrate' = 'tomcat is moving from old interface server'
    '--staged' = 'tomcat and mobiledoc files already in place, do not copy'
    } | Format-list;exit
}

#--Get the tomcat and timezone info if not previously specified
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$TZ){$TZ = $SHOW.time_zone}
if (!$APP){
$APPCID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP = $APPID.a1
          }
if ($MIGRATE)
    {
        $OLDLAB =   $SHOW.interface_server 
    }

#--Get the DB info
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site$SID`_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Check to see if the site already has an interface tomcat
if (!$MIGRATE)
    {
        if ($SHOW.interface_server -like 'lab*' -or $SHOW.interface_server -like 'rpt*')
            {
                Write-Output "Site$SID may already have an interface tomcat. Please verify and update ControlData."
                exit
            }
    }

#--Check network access to source tomcat
$CHECKSMB = Test-Path \\$APP\site$SID
if ($CHECKSMB -eq $FALSE)
    {
        Write-Output "Cannot access source tomcat folder at \\$APP\site$SID. Please confirm and try again."
        exit
    }

$TIME_ARRAY = @("America/Los_Angeles", "Pacific/Honolulu", "America/Denver", "America/Chicago", "America/New_York")
IF ($TZ -eq "PST") { $TIME_ZONE =  $TIME_ARRAY[0] }
IF ($TZ -eq "HST") { $TIME_ZONE =  $TIME_ARRAY[1] }
IF ($TZ -eq "MST") { $TIME_ZONE =  $TIME_ARRAY[2] }
IF ($TZ -eq "CST") { $TIME_ZONE =  $TIME_ARRAY[3] }
IF ($TZ -eq "EST") { $TIME_ZONE =  $TIME_ARRAY[4] }

#--Confirm the Arguments
IF (!$SID){Write-Output "No Site ID specified. Please specify a Site ID by using --site or -s";exit} else {Write-Output "Site number is $SID"}
If (!$TZ) {write-output "No Time Zone specified. Using server default, Pacific"} else {Write-Output "Time Zone is $TZ, $TIME_ZONE"}
if (!$MIN) {$MIN = 16}
if (!$MAX) {$MAX = 96}
if (!$TOMCATVER){$TOMCATDIR = 'tomcat8'} 
else{
if ($TOMCATVER -is [int]){$TOMCATDIR = "tomcat$TOMCATVER"} else {Write-Output 'Specify Tomcat version as an Integer';exit }
}

#--Display installation details
[PSCustomObject] @{
  Site     = $SID
  Appserver= $APP
  Timezone = "$TZ, $TIME_ZONE"
  Minimum  = "$MIN MB"
  Maximum  = "$MAX MB" 
} | Format-list

#--Confirmation from user
if ($PROCEED -eq 'FALSE')
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = Read-Host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting install..."}

#--Copy the local $TOMCATDIR template to c:\alley\site"$SID"\
if (!$STAGED)
    {
        Write-Host -NoNewline "Copying local Tomcat files..."
        robocopy /COPYALL /E /NFL /NDL /NJH /NJS /nc /ns "c:\alley\_template (Do Not Delete)\$TOMCATDIR" c:\alley\site$SID\$TOMCATDIR\
        Write-host "Done"
    }
#--Zip & Copy the mobiledoc folder from the application tomcat, and unzip at the destination
if (!$STAGED)
    {
            if (Test-Path \\$APP\site$SID\tomcat8) { $APPTOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP\site$SID\tomcat7) { $APPTOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP\site$SID\tomcat6) { $APPTOMCATDIR = 'tomcat6' }
                        }
                }
        Write-Host -NoNewline "Zipping Application Tomcat files..."
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP "cd /alley/site$SID/$APPTOMCATDIR/webapps;7za a -tzip mobiledoc_IF_install.zip mobiledoc"
        Write-host "Done"
        Write-Host -NoNewline "Copying Application Tomcat zip file..."
        cpi \\$APP\site$SID\$APPTOMCATDIR\webapps\mobiledoc_IF_install.zip c:\alley\site$SID\$TOMCATDIR\webapps\
        Write-host "Done"
        Write-Host -NoNewline "Un-Zipping Application Tomcat files..."
        & "c:\program files\7-zip\7z.exe" x "c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc_IF_install.zip" -oc:\alley\site$SID\$TOMCATDIR\webapps\ -y
        Write-host "Done"    
    }


#--Configure the tomcat ports
Write-Output "Setting site$SID server.xml port..."
Replace-FileString.ps1 -pattern '001' -replacement $SID -path c:\alley\site$SID\$TOMCATDIR\conf\server.xml -overwrite
Write-Output "Setting site$SID catalina.properties port..."
Replace-FileString.ps1 -pattern '001' -replacement $SID -path c:\alley\site$SID\$TOMCATDIR\conf\catalina.properties -overwrite
Write-Output "Setting site$SID tomcat-env.sh port..."
Replace-FileString.ps1 -pattern '001' -replacement $SID -path c:\alley\site$SID\$TOMCATDIR\conf\tomcat-env.sh -overwrite

#--Disable job tags on application tomcat mobiledoccfg.properties file
if (!$MIGRATE)
    {
        Write-Output "Disabling jobs on $APP for Site$SID, Press Ctrl+C to cancel"
        timeout 5|Out-Null
        Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update serverdetails set isDefaultJobServer = 0;"
        Replace-FileString.ps1 -pattern 'mobiledoc.DisableSureScript=NO' -replacement 'mobiledoc.DisableSureScript=YES' -path \\$APP\site$SID\$APPTOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
        Replace-FileString.ps1 -pattern 'mobiledoc.DisableEcwSchJobs=NO' -replacement 'mobiledoc.DisableEcwSchJobs=YES' -path \\$APP\site$SID\$APPTOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
        Replace-FileString.ps1 -pattern 'mobiledoc.DisableRxHub=NO' -replacement 'mobiledoc.DisableRxHub=YES' -path \\$APP\site$SID\$APPTOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
    }

#--Enable job tags on interface tomcat mobiledoccfg.properties file
if ($MIGRATE)
    {
        #--Get the tomcat service version and path from old lab server
         $SERVICE = gwmi -ComputerName $OLDLAB win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
         $OLDTOMCATVER = $SERVICE.pathname.split('\')[3]

        cpi -Force \\$OLDLAB\c$\alley\site$SID\$OLDTOMCATVER\webapps\mobiledoc\conf\mobiledoccfg.properties c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties
    }
        else
            {
                Write-Output "Enabling jobs on localhost for Site$SID, Press Ctrl+C to cancel"
                timeout 5|Out-Null
                Replace-FileString.ps1 -pattern 'mobiledoc.DisableSureScript=YES' -replacement 'mobiledoc.DisableSureScript=NO' -path c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
                Replace-FileString.ps1 -pattern 'mobiledoc.DisableEcwSchJobs=YES' -replacement 'mobiledoc.DisableEcwSchJobs=NO' -path c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
                Replace-FileString.ps1 -pattern 'mobiledoc.DisableRxHub=YES' -replacement 'mobiledoc.DisableRxHub=NO' -path c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties -overwrite
            }

#--Install tomcat
$env:CATALINA_HOME = "c:\alley\site$SID\$TOMCATDIR"
#Set-Variable -Name CATALINA_HOME -Value c:\alley\site$SID\$TOMCATDIR
Replace-FileString.ps1 -pattern '%TIME_ZONE%' -replacement $TIME_ZONE -path $env:CATALINA_HOME\bin\service.bat -overwrite
Replace-FileString.ps1 -pattern '32' -replacement $MIN -path $env:CATALINA_HOME\bin\service.bat -overwrite
Replace-FileString.ps1 -pattern '128' -replacement $MAX -path $env:CATALINA_HOME\bin\service.bat -overwrite


#If ($TOMCATDIR -eq 'tomcat6'){cmd /c "set_tomcat_home.bat $SID"}
#If ($TOMCATDIR -eq 'tomcat7'){cmd /c "set_tomcat_home7.bat $SID"}
Write-Host "Installing $TOMCATDIR"
cd $env:CATALINA_HOME\bin
cmd /c "service.bat install $SID"

#--Verify installation and update ControlData
if (!$NOSTART)
    {
        Start-Service $SID
        timeout 30|Out-Null
        $INSTALLED = checkdb "-s=$SID" "--host=$HOSTNAME"
        if ($installed[2] -eq 'Check DB Connection Succeeded')
            {Write-Output "Installation successful. Updating ControlData"
             invoke-mysql --site=000 --query="update sitetab set interface_server = '$HOSTNAME' where siteid = $SID limit 1;"
             }
    }

#--Cleanup zip files
Write-Host -NoNewline "Removing local mobiledoc_IF_install.zip file..."
Remove-Item -Force c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc_IF_install.zip
Write-Host "Done"
Write-Host -NoNewline "Removing app server mobiledoc_IF_install.zip file..."
plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP "cd /alley/site$SID/$APPTOMCATDIR/webapps;rm -f mobiledoc_IF_install.zip"
Write-Host "Done"