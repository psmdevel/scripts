#--v11.40 ensure \mobiledoc\jsp\ext\jquery-ui-1.9.1 folder is named in lower-case

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}            
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}
    }





#--Test and confirm variables
If (!$m_SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
#If (!$m_INTERFACE -and !$APPSERVER -and !$m_A -and !$m_B){Write-Host "No tomcats specified. Please use --interface or --app";exit}
#If (!$PATCH) {Write-Host "Please specify a patch number with -p= or --patch=";exit}
#If ($APPSERVER -and $m_A -or $APPSERVER -and $m_B) {Write-Host "--app encompasses both application tomcats. Please specify --app or -a/-b";exit}

#--Get tomcat server hostnames
$m_SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $m_SID;"
$m_APPCID = $m_SHOW.app_cluster_id[0]
$m_APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $m_APPCID;"
$m_APP1 = $m_APPID.a1
$m_APP2 = $m_APPID.a2
#$LABHOST = $m_SHOW.interface_server
#if ($LABHOST -notlike 'lab*'){$LABHOST = $NULL}

<#--Get tomcat directory
if ($LABHOST)
    {   
        $SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$m_SID"}|select name, displayname, startmode, state, pathname, processid
        $LABTOMCATDIR = $SERVICE.pathname.split('\')[3]
    } #>


if (Test-Path \\$m_APP1\site$m_SID\tomcat8) { $APP1TOMCATDIR = 'tomcat8' }
    else
        {
            if (Test-Path \\$m_APP1\site$m_SID\tomcat7) { $APP1TOMCATDIR = 'tomcat7' }
            else 
                {
                    if (Test-Path \\$m_APP1\site$m_SID\tomcat6) { $APP1TOMCATDIR = 'tomcat6' }
                }
        }
if (Test-Path \\$m_APP2\site$m_SID\tomcat8) { $APP2TOMCATDIR = 'tomcat8' }
    else
        {
            if (Test-Path \\$m_APP2\site$m_SID\tomcat7) { $APP2TOMCATDIR = 'tomcat7' }
            else 
                {
                    if (Test-Path \\$m_APP2\site$m_SID\tomcat6) { $APP2TOMCATDIR = 'tomcat6' }
                }
        }

#--Check the case of the jquery folders
$JQCHK1_1 = Get-ChildItem -path \\$m_APP1\site$m_SID\$APP1TOMCATDIR\webapps\mobiledoc\jsp\ext\ -name|select-string -CaseSensitive 'JQUERY-UI-1.9.1'
$JQCHK2_1 = Get-ChildItem -path \\$m_APP2\site$m_SID\$APP2TOMCATDIR\webapps\mobiledoc\jsp\ext\ -name|select-string -CaseSensitive 'JQUERY-UI-1.9.1'

if ($JQCHK1_1)
    {
        write-host -NoNewline "$m_SID`@$m_APP1`: Moving 'JQUERY-UI-1.9.1' to 'jquery-ui-1.9.1'"
        plink -i M:\scripts\sources\ts01_privkey.ppk root@$m_APP1 "cd /alley/site$m_SID/$APP1TOMCATDIR/webapps/mobiledoc/jsp/ext/;mv -f JQUERY-UI-1.9.1 jquery-ui-1.9.1"
        $JQCHK1_2 = Get-ChildItem -path \\$m_APP1\site$m_SID\$APP1TOMCATDIR\webapps\mobiledoc\jsp\ext\ -name|select-string -CaseSensitive 'JQUERY-UI-1.9.1'
        if (!$JQCHK1_2)
                {write-host -ForegroundColor Green "[OK]"}
                    else
                        {write-host -ForegroundColor Red "[FAIL]"}
    }
            


if ($JQCHK2_1)
    {
        write-host -NoNewline "$m_SID`@$m_APP2`: Moving 'JQUERY-UI-1.9.1' to 'jquery-ui-1.9.1'"
        plink -i M:\scripts\sources\ts01_privkey.ppk root@$m_APP2 "cd /alley/site$m_SID/$APP2TOMCATDIR/webapps/mobiledoc/jsp/ext/;mv -f JQUERY-UI-1.9.1 jquery-ui-1.9.1"
        $JQCHK2_2 = Get-ChildItem -path \\$m_APP2\site$m_SID\$APP2TOMCATDIR\webapps\mobiledoc\jsp\ext\ -name|select-string -CaseSensitive 'JQUERY-UI-1.9.1'
        if (!$JQCHK2_2)
                {write-host -ForegroundColor Green "[OK]"}
                    else
                        {write-host -ForegroundColor Red "[FAIL]"}
    }