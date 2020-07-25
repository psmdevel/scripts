#--Enable stuck thread valve via server.xml

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module M:\scripts\sources\_functions.psm1 -Force

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
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -like 'i*')
    {Write-Host "Site$SID does not exist or is inactive";exit}

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -Site 000 -Query "select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

#--Get the tomcat versions                
$APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
$APP2_TC_VERSION = Connect-Ssh -ComputerName $APP2 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"

if ($APP1_TC_VERSION -eq 7)
    {
        #--Check if logging is configured correctly in the server.xml
        $SRV1PATH = "\\$APP1\site$SID\tomcat7\conf\server.xml"
        [xml]$SRV1 = Get-Content $SRV1PATH
        if (!($SRV1.Server.Service.Engine.Host.valve|where {$_.classname -like '*stuck*'}))
            {
                #echo "update this server.xml"
                $UPDATEXML1 = $TRUE
                $newvalve = $SRV1.Server.Service.engine.host.AppendChild($SRV1.CreateElement("Valve"))
                $newvalve.SetAttribute("className","org.apache.catalina.valves.StuckThreadDetectionValve")
                $newvalve.SetAttribute("threshold","3")
                $SRV1.Server.Service.Engine.Host.AppendChild($newvalve)
                #$server.Save("$SRV1PATH")
            } 
                    else 
                        {echo "don't update this server.xml"}
        if ($UPDATEXML1)
            {
                write-host -NoNewline "Site$SID - Update server.xml on $APP1`: [True]"
                $SRV1.Save($SRV1PATH)
                [xml]$SRV1TEST = Get-Content $SRV1PATH
                if ($SRV1.Server.Service.Engine.Host.valve|where {$_.classname -like '*stuck*'})
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
        if (!($SRV2.Server.Service.Engine.Host.valve|where {$_.classname -like '*stuck*'}))
            {
                #echo "update this server.xml"
                $UPDATEXML2 = $TRUE
                $newvalve = $SRV2.Server.Service.engine.host.AppendChild($SRV2.CreateElement("Valve"))
                $newvalve.SetAttribute("className","org.apache.catalina.valves.StuckThreadDetectionValve")
                $newvalve.SetAttribute("threshold","3")
                $SRV2.Server.Service.Engine.Host.AppendChild($newvalve)
            } 
                    else 
                        {echo "don't update this server.xml"}
        if ($UPDATEXML2)
            {
                write-host -NoNewline "Site$SID - Update server.xml on $APP2`: [True]"
                $SRV2.Save($SRV2PATH)
                [xml]$SRV2TEST = Get-Content $SRV2PATH
                if ($SRV2.Server.Service.Engine.Host.valve|where {$_.classname -like '*stuck*'})
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
            }
    }