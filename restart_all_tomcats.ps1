#--Restart all job server tomcats
$DRIVE = (Get-Location).Drive.Root
$LOGFILE = "$DRIVE\scripts\logs\restart_all_tomcats.log"
$FORMAT = 'yyyy-MM-dd-hh:mm:ss'
#--Get the list of stopped tomcats
$SERVICES = gwmi win32_service| ?{$_.Displayname -like 'apache tomcat*' -and $_.StartMode -like 'auto*'}|select name, displayname, startmode, status, pathname, processid

#--Start logging
Write-Output "$(Get-Date -Format $FORMAT): ######################################################" |Out-File $LOGFILE -Append
Write-Output "$(Get-Date -Format $FORMAT): Script started" |Out-File $LOGFILE -Append
Write-Output "$(Get-Date -Format $FORMAT): ######################################################" |Out-File $LOGFILE -Append



#--Restart each tomcat
foreach ($SERVICE in $SERVICES)
    {
        #--Define some variables for aspects of the service
        $SID = $SERVICE.name
        $SIDPID = $SERVICE.processid
        $DISPLAYNAME = $SERVICE.displayname
        Write-Output "$(Get-Date -Format $FORMAT): Processing site$SID with PID $SIDPID" |Out-File $LOGFILE -Append
        Write-Output "$(Get-Date -Format $FORMAT): Stopping tomcat $SID"|Out-File $LOGFILE -Append
        #--Stop the service, quickly
        Stop-Service $SID -NoWait -Force
        #--Pause a moment for the service to stop
        timeout 20|Out-Null
        #--Check to see if the service stopped properly
        $CHECK1 = Get-Service $SID
        if ($CHECK1.Status -ne 'Stopped')
            {
                #--Take note of the stubborness of the service, and force it to quit
                Write-Output "$(Get-Date -Format $FORMAT): $DISPLAYNAME process $SIDPID is still running" |Out-File $LOGFILE -Append
                Write-Output "$(Get-Date -Format $FORMAT): Killing PID $SIDPID by brute force"|Out-File $LOGFILE -Append
                kill -Force $SIDPID -ErrorAction SilentlyContinue
                timeout 5|Out-Null
                #--Check the fruits of your labor
                if (Get-Process -PID $SIDPID -ErrorAction SilentlyContinue)
                    {
                        #--Log your displeasure with the service not responding to your repeated commands
                        Write-Output "$(Get-Date -Format $FORMAT): The cheeky bastard refuses to die"|Out-File $LOGFILE -Append
                        Write-Output "$(Get-Date -Format $FORMAT): Lawd above! Seein' as 'ow da bastard refused ter die, i' doesn't make any sense ter tell 'im ter start again, does it?"|Out-File $LOGFILE -Append
                    }
                        else
                            {
                                Write-Output "$(Get-Date -Format $FORMAT): Killed PID $SIDPID"|Out-File $LOGFILE -Append
                            }
            }
        $CHECK2 = Get-Service $SID
        #$CHECK2.Status -eq 'Stopped'
        if ($CHECK2.Status -eq 'Stopped')
            {   
        
                #--Start the service again
                Write-Output "$(Get-Date -Format $FORMAT): Starting tomcat $SID"|Out-File $LOGFILE -Append
                Start-Service $SID
                #--Pause another moment for it to start 
                timeout 10|Out-Null
                #--Check to make sure it's running again
                $CHECK3 = Get-Service $SID
                if ($CHECK3.status -eq 'Running')
                    {
                        #--Heap praise upon the obedient service and note down that it deserves a cookie
                        Write-Output "$(Get-Date -Format $FORMAT): $DISPLAYNAME for site$SID is running"|Out-File $LOGFILE -Append
                    }
                        else
                            {
                                #--Frown upon the delinquent service and log its inability to resume its duties
                                Write-Output "$(Get-Date -Format $FORMAT): $DISPLAYNAME for site$SID did not start"|Out-File $LOGFILE -Append
                            }
            }
        Write-Output "$(Get-Date -Format $FORMAT): ----------------"|Out-File $LOGFILE -Append
    }
#--Announce that you're done for the night. You'll be back tomorrow. Recommend the veal.
Write-Output "$(Get-Date -Format $FORMAT): -------Script Complete---------"|Out-File $LOGFILE -Append