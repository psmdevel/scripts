#--Check Tomcat Memory on linux tomcat servers
#$SID = '622'
#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '-a') {$A = $TRUE}
        if ($L -eq '-b') {$B = $TRUE}
        if ($L -eq '--both') {$BOTH = $TRUE}
        if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = $TRUE}
        #if ($L -eq '--interface' -or $L -eq '-i') {$INTERFACE = $TRUE}
    }


#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Update JDK version on Linux tomcat servers"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'-a|-b|--both' = "Specify the tomcats to check. Defaults to --both"
'--proceed|-y' = "Proceed with update without prompting"
                }|Format-List; exit
            }
#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--If no tomcats specified, assume both should be checked
If (!$BOTH -and !$A -and !$B -and !$INTERFACE)
    {
        $BOTH = $TRUE
        $A = $TRUE
        $B = $TRUE
    }

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -Site 000 -Query "select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
if ($INTERFACE)
    {
        if ($SHOW.interface_server -like 'lab*')
            {
                $INT = $SHOW.interface_server
            }
                else
                    {
                        Write-Host "Interface server was specified, but site does not have an interface server listed. Exiting.";exit
                    }
    }

#--Determine the tomcats to update JDK
$APPARRAY = @()
if ($BOTH) {$APPARRAY += $APP1, $APP2}
    else
        {if ($A) {$APPARRAY += $APP1}
         if ($B) {$APPARRAY += $APP2}
         if ($INT) {$APPARRAY += $INT}
        }
if (!$A)
    {
        $UPDATE_A = 'Skipped'
    }
if (!$B)
    {
        $UPDATE_B = 'Skipped'
    }
#--update JDK on the specified tomcats
$UPDATE_ARRAY = @()
if ($A)
    {
        if (-not (Test-Path \\$APP1\site$SID\tomcat7))
            {
                echo "Site tomcat not on tomcat 7. Exiting";exit
            }
        if (-not (Test-Path \\$APP1\site$SID\tomcat7\conf\tomcat-env.sh))
            {
                echo "Could not access tomcat-env.sh file. Exiting";exit
            }
        $UPDATE = New-Object system.object
        $TESTJDK = (((get-content \\$APP1\site$SID\tomcat7\conf\tomcat-env.sh|select-string JAVA_HOME).ToString()).Split('"')[-2]).split('/')[-1]
        if ($TESTJDK -ne 'jdk1.8.0_152') 
            {
                $UPDATE|Add-Member -Type NoteProperty -Name App -Value "$APP1"
                $UPDATE|Add-Member -Type NoteProperty -Name Update -Value "$TRUE"
                $UPDATE_ARRAY += $UPDATE
                $UPDATE_A = $TRUE
            }
                else
                    {
                        $UPDATE_A = $FALSE
                    }
    }
if ($B)
    {
        if (-not (Test-Path \\$APP2\site$SID\tomcat7))
            {
                echo "Site tomcat not on tomcat 7. Exiting";exit
            }
        if (-not (Test-Path \\$APP2\site$SID\tomcat7\conf\tomcat-env.sh))
            {
                echo "Could not access tomcat-env.sh file. Exiting";exit
            }
        $UPDATE = New-Object system.object
        $TESTJDK = (((get-content \\$APP2\site$SID\tomcat7\conf\tomcat-env.sh|select-string JAVA_HOME).ToString()).Split('"')[-2]).split('/')[-1]
        if ($TESTJDK -ne 'jdk1.8.0_152') 
            {
                $UPDATE|Add-Member -Type NoteProperty -Name App -Value "$APP2"
                $UPDATE|Add-Member -Type NoteProperty -Name Update -Value "$TRUE"
                $UPDATE_ARRAY += $UPDATE
                $UPDATE_B = $TRUE
            }
                else
                    {
                        $UPDATE_B = $FALSE
                    }
    }
<#foreach ($APP in $APPARRAY)
    {
        if (-not (Test-Path \\$APP\site$SID\tomcat7))
            {
                echo "Site tomcat not on tomcat 7. Exiting";exit
            }
        if (-not (Test-Path \\$APP\site$SID\tomcat7\conf\tomcat-env.sh))
            {
                echo "Could not access tomcat-env.sh file. Exiting";exit
            }
        $UPDATE = New-Object system.object
        $TESTJDK = (((get-content \\$APP\site$SID\tomcat7\conf\tomcat-env.sh|select-string JAVA_HOME).ToString()).Split('"')[-2]).split('/')[-1]
        if ($TESTJDK -ne 'jdk1.8.0_152') 
            {
                $UPDATE|Add-Member -Type NoteProperty -Name App -Value "$APP"
                $UPDATE|Add-Member -Type NoteProperty -Name Update -Value "$TRUE"
                $UPDATE_ARRAY += $UPDATE
            }
    }#>

#$UPDATE_ARRAY

[PSCustomObject] @{
  'Update_A' = $APP1,$UPDATE_A 
  'Update_B' = $APP2,$UPDATE_B
  
} | Format-list
if ($UPDATE_ARRAY.count -eq 0)
    {
        Write-Host "JDK already up to date. Exiting.";exit
    }
#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {
                Write-host "PROCEED specified. Updating JDK"
            }

foreach ($APP in $UPDATE_ARRAY.app)
    {
        write-host -NoNewline "Updating $APP "
        Replace-FileString.ps1 -pattern "$TESTJDK" -replacement 'jdk1.8.0_152' -path \\$APP\site$SID\tomcat7\conf\tomcat-env.sh -overwrite
        $TESTJDK2 = (((get-content \\$APP\site$SID\tomcat7\conf\tomcat-env.sh|select-string JAVA_HOME).ToString()).Split('"')[-2]).split('/')[-1]
        if ($TESTJDK2 -eq 'jdk1.8.0_152')
            {
                Write-Host -ForegroundColor Green "[OK]"
            }
                else
                    {
                        Write-Host -ForegroundColor Red "[FAIL]"
                    }
    }