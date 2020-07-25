#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
        if ($L -eq '--timezone' -or $L -eq '-tz'){$TZ = $R}
        if ($L -eq '--version' -or $L -eq '-ver' -or $L -eq '-v'){$TOMCATVER = [INT]$R}
        if ($L -eq '--proceed' -or $L -eq '-y'){$PROCEED = $TRUE}
    }

#--Verify arguments
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
if (!$TOMCATVER){Write-Host "No tomcat version specified. Please use --version or -ver";exit}
if ($TOMCATVER -is [int]){$TOMCATDIR = "tomcat$TOMCATVER"} else {Write-Output 'Specify Tomcat version as an Integer';exit }

#--Get the tomcat and timezone info if not previously specified
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$TZ){$TZ = $SHOW.time_zone}

$SERVICE = gwmi win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
$OLDTOMCATDIR = $SERVICE.pathname.split('\')[3]

#--Check if the tomcat is already on the specified upgrade version
if ($OLDTOMCATDIR -eq $TOMCATDIR){Write-Host "Site$SID is already on $TOMCATDIR";exit}


# $TZ = (mysqlsite --site=000 select TIME_ZONE from controldata.sitetab where siteid = $SID)
$TIME_ARRAY = @("America/Los_Angeles", "Pacific/Honolulu", "America/Denver", "America/Chicago", "America/New_York")
IF ($TZ -eq "PST") { Set-Variable -n TIME_ZONE -val $TIME_ARRAY[0] }
IF ($TZ -eq "HST") { Set-Variable -n TIME_ZONE -val $TIME_ARRAY[1] }
IF ($TZ -eq "MST") { Set-Variable -n TIME_ZONE -val $TIME_ARRAY[2] }
IF ($TZ -eq "CST") { Set-Variable -n TIME_ZONE -val $TIME_ARRAY[3] }
IF ($TZ -eq "EST") { Set-Variable -n TIME_ZONE -val $TIME_ARRAY[4] }

# Get the Min and Max Memory from the existing Tomcat service
if ($OLDTOMCATDIR -eq 'tomcat7' -or $OLDTOMCATDIR -eq 'tomcat8')
    {
	    $MIN = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\$SID\Parameters\Java") | Select-Object -ExpandProperty JvmMs
	    $MAX = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Apache Software Foundation\Procrun 2.0\$SID\Parameters\Java") | Select-Object -ExpandProperty JvmMx
    }
if ($OLDTOMCATDIR -eq 'tomcat6')
    {
        $MIN = (Get-ItemProperty "HKLM:\SOFTWARE\Apache Software Foundation\Procrun 2.0\$SID\Parameters\Java") | Select-Object -ExpandProperty JvmMs
        $MAX = (Get-ItemProperty "HKLM:\SOFTWARE\Apache Software Foundation\Procrun 2.0\$SID\Parameters\Java") | Select-Object -ExpandProperty JvmMx
    }
#--Echo the upgrade parameters
[PSCustomObject] @{
  Site     = $SID
  Timezone = "$TZ, $TIME_ZONE"
  Minimum  = "$MIN MB"
  Maximum  = "$MAX MB"
  Version = "$TOMCATDIR" 
} | Format-list

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting upgrade..."}

# Stop and delete the existing tomcat service
$SERVICE = gwmi win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
Stop-Service $SERVICE.name
$SIDPID = $SERVICE.processid
if ($SERVICE.state -ne 'stopped') {Write-host -NoNewline "Tomcat process still running, terminating..."; Stop-Process -Force $SIDPID|Out-Null; Write-Host "Done"}
sc.exe delete $SID

# copy the Tomcat files into place
Write-Output "Copying $TOMCATDIR Template"
robocopy /COPYALL /E /NFL /NDL /NJH /NJS /nc /ns "C:\alley\_template (Do Not Delete)\$TOMCATDIR" c:\alley\site$SID\$TOMCATDIR\

# Move the tomcat/mobiledoc folder
Write-Output 'Moving Mobiledoc Folder'
Move-Item c:\alley\site$SID\$OLDTOMCATDIR\webapps\mobiledoc c:\alley\site$SID\$TOMCATDIR\webapps\ -Force
Move-Item c:\alley\site$SID\$OLDTOMCATDIR\webapps\*.war c:\alley\site$SID\$TOMCATDIR\webapps\
Move-Item c:\alley\site$SID\$OLDTOMCATDIR\webapps\rxeducation c:\alley\site$SID\$TOMCATDIR\webapps\rxeducation -ErrorAction SilentlyContinue -Force
Move-Item c:\alley\site$SID\$OLDTOMCATDIR\eHX_data c:\alley\site$SID\$TOMCATDIR\ -ErrorAction SilentlyContinue -Force

# Configure the server.xml and catalina.properties
Write-Output "Setting site$SID server.xml port"
Replace-FileString.ps1 -pattern '001' -replacement $SID -path c:\alley\site$SID\$TOMCATDIR\conf\server.xml -overwrite
Write-Output "Setting site$SID catalina.properties port"
Replace-FileString.ps1 -pattern '001' -replacement $SID -path c:\alley\site$SID\$TOMCATDIR\conf\catalina.properties -overwrite

# Set Min and Max Memory and timezone
Write-Output 'Allocating Memory'
Write-Output "Minimum = $MIN"
Write-Output "Maximum = $MAX"
Replace-FileString.ps1 -pattern '16' -replacement $MIN -path c:\alley\site$SID\$TOMCATDIR\bin\service.bat -overwrite
Replace-FileString.ps1 -pattern '96' -replacement $MAX -path c:\alley\site$SID\$TOMCATDIR\bin\service.bat -overwrite
Replace-FileString.ps1 -pattern '%TIME_ZONE%' -replacement $TIME_ZONE -path c:\alley\site$SID\$TOMCATDIR\bin\service.bat -overwrite

# Install Tomcat
Write-Host "Installing $TOMCATDIR"
If ($TOMCATDIR -eq 'tomcat6'){$env:CLASSPATH = "C:\eClinicalWorks\jdk16\lib"; $env:JAVA_HOME = "C:\eClinicalWorks\jdk16"}
If ($TOMCATDIR -eq 'tomcat7'){$env:CLASSPATH = "C:\eClinicalWorks\jdk17\lib"; $env:JAVA_HOME = "C:\eClinicalWorks\jdk17"}
If ($TOMCATDIR -eq 'tomcat8'){$env:CLASSPATH = "C:\eClinicalWorks\jdk18\lib"; $env:JAVA_HOME = "C:\eClinicalWorks\jdk18"}
$env:CATALINA_HOME = "c:\alley\site$SID\$TOMCATDIR"
cd $env:CATALINA_HOME\bin
cmd /c "service.bat install $SID"
#cmd /c "set_tomcat$TOMCATVER`_home.bat $SID"
Write-Host -NoNewline "Setting tomcat startup to Automatic..."
Set-Service $SID -StartupType Automatic
Write-Host "Done"
Write-Host "Starting service"
start-service $SID
timeout 30|out-null

#--Cleanup
$INSTALLED = checkdb --site=$SID
        if ($installed[2] -eq 'Check DB Connection Succeeded')
            {
                Write-Host "Installation successful. Cleaning up old tomcat folder..."
                #& "c:\program files\7-zip\7z.exe" a -tzip -mx=9 "c:\alley\site$SID\$OLDTOMCATDIR.zip" "c:\alley\site$SID\$OLDTOMCATDIR"
                Remove-Item -Recurse c:\alley\site$SID\$OLDTOMCATDIR
                Write-Host "Cleanup complete"
            }