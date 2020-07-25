#--restarts the ftpgetter service unless someone is in the gui

#--Define the variables
filter timestamp {"$(get-date -format G): $_"}
$HOSTNAME = hostname
$DRIVE = (Get-Location).Drive.Root
$LOGFILE = "$DRIVE\scripts\logs\restart_ftpgetter.log"
$FGService = 'FTPGetterLauncher'
$FGHome = "$DRIVE\ProgramData\FTPGetter"
$FGSettings = Get-ChildItem "$FGHome\settings.xml"

#--Start logging
Write-Output "----------------------------------------------------------"|timestamp|Out-File $LOGFILE -Append utf8
Write-Output "script started"|timestamp|Out-File $LOGFILE -Append utf8

#--Check if GUI is running
$FGExe = Get-Process -Name 'FTPGetter' -ErrorAction SilentlyContinue
if ($FGExe){$RestartService = $FALSE} else {$RestartService = $TRUE}

#--Check if settings.xml is corrupted (0kb)
if ($FGSettings.Length -lt 1){$DeleteSettings = $TRUE}

#--If the GUI is running, exit
if ($RestartService -eq $FALSE)
    {
        Write-Output "FTPGetter.exe found running. Restart aborted"|timestamp|Out-File $LOGFILE -Append utf8
        exit      
    }

#--If the GUI is not running, stop the service
if ($RestartService -eq $TRUE)
    {
        Write-Output "stopping ftpgetter service"|timestamp|Out-File $LOGFILE -Append utf8
        Stop-Service $FGService
        Write-Output "sleeping 20 seconds"|timestamp|Out-File $LOGFILE -Append utf8
        timeout 20|Out-Null
        
        #--If the settings.xml file is corrupted, delete it
        if ($DeleteSettings -eq $TRUE)
            {
                Write-Output "settings.xml found corrupted, deleting"|timestamp|Out-File $LOGFILE -Append utf8
                Remove-Item $FGSettings -Force
                timeout 5|Out-Null
                #--Check to make sure it was deleted successfully. Email the admin if it was not deleted
                $DeleteSuccess = Test-Path $FGSettings
                if ($DeleteSuccess -eq $FALSE)
                    {
                        Write-Output "corrupted settings.xml successfully deleted"|timestamp|Out-File $LOGFILE -Append utf8
                    }
                        else
                            {
                                $DATESTAMP1 = timestamp
                                Write-Output "corrupted settings.xml not deleted. Emailing Admin"|timestamp|Out-File $LOGFILE -Append utf8
                                Send-MailMessage -To "Admin <admin@psmnv.com>" -From "restart_ftpgetter@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "FTPGetter on $HOSTNAME found broken" -Body "$FGService service settings.xml on $HOSTNAME found broken at $DATESTAMP1. Please investigate."
                            }
            }
        #--Start the service
        Write-Output "starting ftpgetter service"|timestamp|Out-File $LOGFILE -Append utf8
        Start-Service $FGService
        Write-Output "script complete"|timestamp|Out-File $LOGFILE -Append utf8
    }