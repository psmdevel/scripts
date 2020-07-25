#--Launch the eCW Client for a specified site. Maps drive C:\ from \\TSxx\m$\sites\yyy and launches C:\Program Files\eClinicalWorks\eClinicalWorks.exe

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module M:\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
        if ($L -eq '-a'){$A = 'True'}
        if ($L -eq '-b'){$B = 'True'}
        if ($L -eq '--app'){$APPSRV = $R}
        if ($ARG -eq '--web'){$WEBCLIENT = $TRUE}
    }

#--Test and confirm variables
If (!$SID) {$HELP = $TRUE}
if ($A -and $B){write-host "Please specify either -a or -b, but not both";exit}
if ($APPSRV)
    {
        if ($APPSRV -inotin ('a','b','lab','job','ssl','i'))
            {
                $HELP = $TRUE
            }
    }

#--help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Run eClinicalWorks.exe for the specified site"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number."
'--app' = "Specify tomcat a|b|ssl|lab|job"
'-a|-b' = "Specify terminal server to launch client from"
'--web' = "Launch web client instead of exe"

                }|Format-List; exit
            }

#--Query the Control Data DB for the site info
if ($SID)
     {
        $SHOW = Show-Site --site=$SID --tool
        #$SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"
    }
if ($SHOW.status -notlike 'a*'){Write-Host "Site is inactive. Please try an active site";exit}
$KEYWORDS = $SHOW.keywords

#--Get the terminal server info
$TSCID = $SHOW.ts_cluster_id
$TSID = Invoke-MySQL -Site 000 -query "select * from ts_clusters where id = $TSCID;"
$TS1 = $SHOW.t1
$TS2 = $SHOW.t2
if ($B) {$TS = $TS2}
    else
        {$TS = $TS1}
$TSR1 = Invoke-MySQL -Site 000 -query "select * from ts_properties where name = '$TS';"
#Write-Host "Debug: TSR1 = $TSR1"
#$TSR2 = $TSR.site_root
#Write-Host "Debug: TSR2 = $TSR2"
$TS_ROOT = $TSR1.site_root.split(':')[0]
#Write-Host "Debug: TSR_ROOT = $TS_ROOT"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$JOB = $SHOW.a3
$EXTURL = $SHOW.ext_url_short
#Write-Host "DEBUG: External URL: $EXTURL"
if ($APPSRV)
    {
        if ($APPSRV -eq 'a')
            {
                $CONFURL = "$APP1`:3$SID"
            }
        if ($APPSRV -eq 'b')
            {
                $CONFURL = "$APP2`:3$SID"
            }
        if ($APPSRV -eq 'job' -or $APPSRV -eq 'lab')
            {
                if (!$JOB)
                    {
                        Write-Host "Job or Lab server specified, but not found. Exiting";exit
                    }
                $CONFURL = "$JOB`:3$SID"
            }
        if ($APPSRV -eq 'ssl' -or $APPSRV -eq 'https' -or $APPSRV -eq 'ext')
            {
                $HTTPS = 'YES'
                #--Get external URL
                #$GEUTEST = Test-Path $DRIVE\scripts\sources\ts01_privkey.ppk
                #if ($GEUTEST -eq $true)
                #    {
                #        $EXTURL = $SHOW.ext_url
                #    }
                if (!$WEBCLIENT)
                    {
                        $CONFURL = "$EXTURL`:443"
                    }
                        else
                            {
                                $CONFURL = $EXTURL
                            }
            }
                else
                    {
                        $HTTPS = 'no'
                    }
        if ($WEBCLIENT -and $APPSRV)
            {
                #Write-Host "DEBUG: NO HTTPS!!!"
                #Write-Host "DEBUG: $CONFURL"
                $HTTPS = 'no'
            }
        
    }
if ($WEBCLIENT -and !$APPSRV)
            {
                #Write-Host "DEBUG: YES HTTPS!!!"
                $HTTPS = 'yes'
                $CONFURL = $EXTURL
            }
#--Bring support account current
rsp --site=$SID|Out-Null
if (!$WEBCLIENT)
    {
        #--Map the drive, unmap drive C:\ if exists
        $CHECKC = subst
        if ($CHECKC -like 'C:\*'){Write-Host "Dismounting drive C:\";subst /D c:|Out-Null }
        #Write-host "Debug: \\$TS`\$TS_ROOT`$\sites\$SID"
        #start \\$TS`\$TS_ROOT`$\sites\$SID
        subst C: \\$TS`\$TS_ROOT`$\sites\$SID|Out-Null
        if ($APPSRV)
            {
                $CONFDYN = "c:\Program Files\eClinicalWorks\configuration_dynamic.xml"
                $ECWLNK = "c:\Program Files\eClinicalWorks\eClinicalWorks.lnk"
                if (-not (Test-Path $CONFDYN))
                    {
                        cpi "c:\Program Files\eClinicalWorks\configuration.xml" "c:\Program Files\eClinicalWorks\configuration_dynamic.xml"
                    }
                #--Create eClinicalWorks_dynamic shortcut
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut("c:\Program Files\eClinicalWorks\eClinicalWorks_dynamic.lnk")  
                $shortcut.TargetPath = "c:\Program Files\eClinicalWorks\eClinicalWorks.exe"
                $shortcut.Arguments = "configuration_dynamic.xml"  
                $shortcut.Description = "Launch eClinicalWorks_dynamic"  
                $shortcut.Save()

                #--Save configuration_dynamic.xml with new options
                $CONF = New-Object -TypeName XML
                #[xml]$CONF = Get-Content $CONFDYN
                $CONF.Load($CONFDYN)
                if (-not ($CONF.configdata.https))
                    {
                        $CONF_TMP = $CONF.CreateElement("HTTPS") #|Out-Null
                        $CONF.configdata.AppendChild($CONF_TMP)
                    }
                $CONF.configdata.server = "$CONFURL"
                $CONF.configdata.HTTPS = "$HTTPS" 
                $CONF.Save($CONFDYN)

        #--Get current directory
        $CWD = $PWD.Path
        [PSCustomObject] @{
                        'SiteID' = $SID
                        'Keywords' = $KEYWORDS
                        'Terminal Server' = $TS
                        'Configuration' = 'Custom'
                        'Server' = $CONFURL
                        } | Format-list            
        Write-Host "Launching eCW Client for site$SID"
        #Unblock-File 'c:\Program Files\eClinicalWorks\eClinicalWorks_dynamic.lnk'
        #powershell.exe -executionpolicy bypass -file 'C:\Program Files\eClinicalWorks\eClinicalWorks_dynamic.lnk'
        cd "c:\program files\eclinicalworks"
        .\eClinicalWorks.exe .\configuration_dynamic.xml
        #Start-Process 'C:\Program Files\eClinicalWorks\eClinicalWorks_dynamic.lnk'
        cd $CWD
            }
                else
                    {
                        $CONF = New-Object -TypeName XML
                        $CONF.Load("c:\Program Files\eClinicalWorks\configuration.xml")
                        $CONFURL = $CONF.configdata.server
                        [PSCustomObject] @{
                        'SiteID' = $SID
                        'Keywords' = $KEYWORDS
                        'Terminal Server' = $TS
                        'Configuration' = 'Default'
                        'Server' = $CONFURL
                        } | Format-list
    
                        Write-Host "Launching eCW Client for site$SID"
                        & 'c:\Program Files\eClinicalWorks\eClinicalWorks.exe' #'c:\Program Files\eClinicalWorks\configuration.xml'
                    }
    }
        else
            {
                
                if ($HTTPS -eq 'yes')
                    {
                        #Write-Host "DEBUG: https://$CONFURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
                        Start-Process 'M:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ArgumentList "https://$CONFURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
                    }
                        else
                            {
                                #Write-Host "DEBUG: http://$CONFURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
                                Start-Process 'M:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ArgumentList "http://$CONFURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
                            }
            }