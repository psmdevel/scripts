#--Check Tomcat Memory on linux tomcat servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
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
        if ($L -eq '--interface' -or $L -eq '-i') {$INTERFACE = $TRUE}
        if ($L -eq '--ebo') {$EBO = $TRUE}
    }


#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Check Tomcat Memory on Linux tomcat servers"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'-a|-b|--both|-i|--interface' = "Specify the tomcats to check. Defaults to --both"
                }|Format-List; exit
            }
#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--If no tomcats specified, assume both should be checked
If (!$BOTH -and !$A -and !$B -and !$INTERFACE){$BOTH = $TRUE}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
if ($INTERFACE)
    {
        if ($SHOW.a3 -like 'lab*')
            {
                $INT = $SHOW.a3
            }
                else
                    {
                        Write-Host "Interface server was specified, but site does not have an interface server listed. Exiting.";exit
                    }
    }

#--Determine the tomcats to CTM
$APPARRAY = @()
if ($BOTH) {$APPARRAY += $APP1, $APP2}
    else
        {if ($A) {$APPARRAY += $APP1}
         if ($B) {$APPARRAY += $APP2}
         if ($INT) {$APPARRAY += $INT}
        }

#--CTM on the specified tomcats
$OOM_ARRAY = @()
foreach ($APP in $APPARRAY)
    {
        Write-Output "Checking Site$SID tomcat memory on $APP"
        if ($APP -like 'lab*')
            {
                $SERVICE = gwmi win32_service -ComputerName $INT|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
                $TOMCATDIR = $SERVICE.pathname.split('\')[3]
                $LOGPATH = "\\$INT\c$\alley\site$SID\$tomcatdir\logs\"
            }
                else
                    {
                        $TOMCATDIR = "tomcat" + (plink -i \scripts\sources\ts01_privkey.ppk root@$APP "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1")
                        $LOGPATH = "\\$APP\site$SID\$TOMCATDIR\logs\"
                    }
        #$OOM_ARRAY = @()
        $LOGDATES = @()
        foreach ($LOG in Get-ChildItem -name $LOGPATH\*.log -Include *stderr*,catalina*,localhost* -Exclude '*access*')
            {
                $LOGDATE = $LOG.split('.')[-2]
                $LOGDATES += $LOGDATE
            }
        $LOGDATES = $LOGDATES|sort -Unique
        #Write-host "DEBUG: $LOGDATES"
        $LOGTOTALS = @()
        foreach ($DATE in $LOGDATES)
            {
                $LOGCOUNT = Get-ChildItem -name $LOGPATH\*.$DATE.log -Include *stderr*,catalina*,localhost* -Exclude '*access*'
                $LOGTOTALS += $LOGCOUNT
            }
        $LOGTOTAL = $LOGTOTALS.count
        Write-Host "Scanning $LOGTOTAL logs..."
        foreach ($DATE in $LOGDATES)
            {
                #$LOGCOUNT = (Get-ChildItem -name $LOGPATH\*.$DATE.log -Include *stderr*,catalina*,localhost*).count
                #Write-Host "Scanning $LOGCOUNT logs..."
                foreach ($LOG in Get-ChildItem -name $LOGPATH\*.$DATE.log -Include *stderr*,catalina*,localhost* -Exclude '*access*')
                    {
                        #write-host "DEBUG: $LOG"
                        $OOMLOGS = New-Object System.Object
                        $OOMLOG = get-content -Path $LOGPATH\$LOG|Select-String -Pattern 'outofmemory','permgen space' -Exclude 'dump'
                        if ($OOMLOG)
                            {
                                $MESSAGES = @()
                                #Write-Host "Found OutOfMemory errors in $LOG"
                                foreach ($MESSAGE in $OOMLOG)
                                    {
                                        $MESSAGES += $MESSAGE.Line
                                    }
                                $COUNT = $MESSAGES.count
                                $OOMLOGS | Add-Member -Type NoteProperty -Name Server -Value $APP
                                $OOMLOGS | Add-Member -Type NoteProperty -Name Count -Value $COUNT
                                $OOMLOGS | Add-Member -Type NoteProperty -Name LogName -Value $LOG
                                $OOMLOGS | Add-Member -Type NoteProperty -Name Messages -Value $MESSAGES
                                        
                                <#foreach ($MESSAGE in $OOMLOG)
                                    {
                                        $OOMLOGS | Add-Member -Type NoteProperty -Name Message -Value $MESSAGE
                                    }#>
                                $OOM_ARRAY += $OOMLOGS
                                #$OOMLOGS
                            }
                    }
                        
            }
        if ($OOM_ARRAY.count -lt 1)
                {
                    #Write-Host -NoNewline "No OutOfMemory errors found on $APP"
                    #Write-Host -ForegroundColor Green "[OK]"
                }
                #Invoke-Command -ComputerName $INT -ScriptBlock {ctm --site=$using:SID}|Select-Object LogName,Count,Messages
            
                <#else
                    {
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP /scripts/ctm --site=$SID
                    }#>
    }
$OOM_ARRAY