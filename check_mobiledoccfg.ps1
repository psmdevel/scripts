#--Check mobiledoccfg.properties for all sites local to this server
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname
if ($HOSTNAME -notlike 'lab*'){echo "This script is intended to be used from an interface server. Exiting.";exit}
$SITES = invoke-mysql --site=000 --query="select siteid from sitetab where status = 'active' and interface_server = '$HOSTNAME' order by siteid;"

foreach ($SID in $SITES.siteid)
    {
        $SERVICE = gwmi win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
        $TOMCATDIR = $SERVICE.pathname.split('\')[3]  
        $CFGDBNAME = Get-Content C:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\conf\mobiledoccfg.properties|select-string 'mobiledoc.DBName'|Select-String -NotMatch -Pattern '#'
        Write-output "Site$SID DBName String: $CFGDBNAME"
    }