#--Find duplicate jar files

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
    }

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
if ($SHOW.status -like 'i*')
    {Write-Host "Site$SID does not exist or is inactive";exit}

#--Get the tomcat info
$APPCID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $APPID.a1
$APP2 = $APPID.a2

$JARS = @()
foreach ($s in gci -Path \\$APP1\site$SID\tomcat7\webapps\mobiledoc\WEB-INF\lib\ -name *.jar) 
    {
        $JARS += $s
    }
$JARS = $JARS -replace "[^a-zA-Z]",""|sort
#$JARS = $JARS|sort
$JARS|Group-Object|where {$_.count -gt 1}