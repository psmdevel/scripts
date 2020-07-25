#--Fix log_analyze via server.xml

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

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--If no tomcats specified, assume both should be checked
#If (!$BOTH -and !$A -and !$B){$BOTH = 'True'}

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
if ($SHOW.status -like 'i*')
    {Write-Host "Site$SID does not exist or is inactive";exit}

#--Get the tomcat info
$APPCID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $APPID.a1
$APP2 = $APPID.a2

#--Get the tomcat versions                
$APP1_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP1 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
$APP2_TC_VERSION = plink -i \scripts\sources\ts01_privkey.ppk root@$APP2 "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"

if ($APP1_TC_VERSION -eq 7)
    {
        #--Check if logging is configured correctly in the server.xml
        $SRV1PATH = "\\$APP1\site$SID\tomcat7\conf\server.xml"
        [xml]$SRV1 = Get-Content $SRV1PATH
        if ($SRV1.DocumentElement.Service.LastChild.Host.LastChild.pattern -ne "%a %t %D %r %q %s")
            {
                $CHANGEPATTERN1 = $TRUE
                $SRV1.DocumentElement.Service.LastChild.Host.LastChild.pattern = "%a %t %D %r %q %s"
            }
        if ($SRV1.DocumentElement.Service.LastChild.Host.LastChild.suffix -ne ".log")
            {
                $CHANGESUFFIX1 = $TRUE
                $SRV1.DocumentElement.Service.LastChild.Host.LastChild.suffix = ".log"
            }
        if ($SRV1.DocumentElement.Service.LastChild.Host.LastChild.prefix -ne "localhost_access.")
            {
                $CHANGEPREFIX1 = $TRUE
                $SRV1.DocumentElement.Service.LastChild.Host.LastChild.prefix = "localhost_access."
            }
        if ($CHANGEPATTERN1 -or $CHANGESUFFIX1 -or $CHANGEPREFIX1)
            {
                write-host -NoNewline "Site$SID - Update server.xml on $APP1`: [True]"
                $SRV1.Save($SRV1PATH)
                [xml]$SRV1TEST = Get-Content $SRV1PATH
                if ($SRV1TEST.DocumentElement.Service.LastChild.Host.LastChild.pattern -eq "%a %t %D %r %q %s" -and $SRV1TEST.DocumentElement.Service.LastChild.Host.LastChild.suffix -eq ".log" -and $SRV1TEST.DocumentElement.Service.LastChild.Host.LastChild.prefix -eq "localhost_access.")
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
    }

if ($APP2_TC_VERSION -eq 7)
    {
        #--Check if logging is configured correctly in the server.xml
        $SRV2PATH = "\\$APP2\site$SID\tomcat7\conf\server.xml"
        [xml]$SRV2 = Get-Content $SRV2PATH
        if ($SRV2.DocumentElement.Service.LastChild.Host.LastChild.pattern -ne "%a %t %D %r %q %s")
            {
                $CHANGEPATTERN2 = $TRUE
                $SRV2.DocumentElement.Service.LastChild.Host.LastChild.pattern = "%a %t %D %r %q %s"
            }
        if ($SRV2.DocumentElement.Service.LastChild.Host.LastChild.suffix -ne ".log")
            {
                $CHANGESUFFIX2 = $TRUE
                $SRV2.DocumentElement.Service.LastChild.Host.LastChild.suffix = ".log"
            }
        if ($SRV2.DocumentElement.Service.LastChild.Host.LastChild.prefix -ne "localhost_access.")
            {
                $CHANGEPREFIX2 = $TRUE
                $SRV2.DocumentElement.Service.LastChild.Host.LastChild.prefix = "localhost_access."
            }
        if ($CHANGEPATTERN2 -or $CHANGESUFFIX2 -or $CHANGEPREFIX2)
            {
                write-host -NoNewline "Site$SID - Update server.xml on $APP2`: [True]"
                $SRV2.Save($SRV2PATH)
                [xml]$SRV2TEST = Get-Content $SRV2PATH
                if ($SRV2TEST.DocumentElement.Service.LastChild.Host.LastChild.pattern -eq "%a %t %D %r %q %s" -and $SRV2TEST.DocumentElement.Service.LastChild.Host.LastChild.suffix -eq ".log" -and $SRV2TEST.DocumentElement.Service.LastChild.Host.LastChild.prefix -eq "localhost_access.")
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
    }