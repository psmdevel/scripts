#--set permissions on linux tomcat servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
Import-Module Posh-SSH

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '-a' -or $L -eq '--a') {$A = 'True'}
        if ($L -eq '-b' -or $L -eq '--b') {$B = 'True'}
        if ($L -eq '--both') {$BOTH = 'True'}
        if ($L -eq '--unlock') {$UNLOCK = '--unlock'}
    }

#--Display available options
if ($HELP)
{
[PSCustomObject] @{
'--site|-s' = 'specify the site number'
'--help|-h' = 'display available options'
'-a|-b' = 'specify tomcat A or B'
'--both'= 'specify both tomcats'
'--unlock' = 'set permissions and unlock immutable files (e.g., web.xml)'
} | Format-list;exit
}

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$KEYFILE = "$DRIVE\scripts\sources\secure\ts01_privkey_openssh.key"
$SSH_AUTH =  New-Object System.Management.Automation.PSCredential("root",(New-Object System.Security.SecureString))

#--Determine the tomcats to set permissions
$APPARRAY = @()
if ($BOTH) {$APPARRAY += $APP1, $APP2}
    else
        {if ($A) {$APPARRAY += $APP1}
         if ($B) {$APPARRAY += $APP2}
        }

        <#Write-Host "Appservers = $APPARRAY"
        Write-Host "Both = $BOTH"
        Write-Host "A = $A"
        Write-Host "B = $B"
        #>

#--Set permissions on the specified tomcats
foreach ($APP in $APPARRAY)
    {
        #$SSH_SESSION = New-SSHSession -ComputerName $APP -Credential $SSH_AUTH -KeyFile $KEYFILE -AcceptKey
        Write-Output "~: Setting Site$SID tomcat permissions on $APP"
        Connect-Ssh -ComputerName $APP -ScriptBlock "/scripts/setperms --site=$SID $UNLOCK"
        #Invoke-SSHCommandStream -SessionId $SSH_SESSION.sessionid -Command "/scripts/setperms --site=$SID $UNLOCK"
        #Remove-SSHSession -SessionId $SSH_SESSION.sessionid|Out-Null
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP /scripts/setperms --site=$SID $UNLOCK
    }