#--Restarts stopped Print Spooler service, and notifies admin@psmnv.com

#--Get the hostname and current date/time
$HOSTNAME = hostname
$DATESTAMP1 = Get-Date -Format yyyy-MM-dd-hh:mm:ss

#--Check if the Print Spooler service is running
$SPOOL = gwmi  win32_service|where{$_.displayname -like "*spooler*" -and $_.state -ne "Running"}
$STATE1 = $SPOOL.state

#--Debug
Write-Output "Debug: Script restart_stopped_spooler.ps1 ran on $HOSTNAME at $DATESTAMP1"|Out-File M:\scripts\logs\restart_stopped_spooler.log -Append

#--If the Print Spooler service is not running, notify admin via email and attempt to restart the service
if ($SPOOL)
 {
    Stop-Process -Name spoolsv -Force
    Send-MailMessage -To "Admin <admin@psmnv.com>" -From "restart_stopped_spooler@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "Spooler on $HOSTNAME found $STATE1" -Body "Print Spooler service on $HOSTNAME found $STATE1 at $DATESTAMP1. Attempting restart"
    Start-Service spooler
 }
    else
        {exit}
            
 #--Check if the Spooler Service started successfully
 $DATESTAMP2 = Get-Date -Format yyyy-MM-dd-hh:mm:ss
 $SPOOL2 = gwmi  win32_service|where{$_.displayname -like "*spooler*" -and $_.state -eq "Running"}

 #--Notify admin of success or failure
 if ($SPOOL2)
    {
        Send-MailMessage -To "Admin <admin@psmnv.com>" -From "restart_stopped_spooler@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "Spooler on $HOSTNAME restarted successfully" -Body "Print Spooler service on $HOSTNAME restarted successfully at $DATESTAMP2."
	exit
    }
        else
            {
                Send-MailMessage -To "Admin <admin@psmnv.com>" -From "restart_stopped_spooler@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "Spooler on $HOSTNAME could not start" -Body "Print Spooler service on $HOSTNAME failed to start at $DATESTAMP2 Please check server $HOSTNAME."
	exit
            }


      