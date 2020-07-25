#--safe_tomcat

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
Import-Module SimplySql
Import-Module Posh-SSH

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '--start') {$START = '--start'}
        if ($L -eq '--stop') {$STOP = '--stop'}
        if ($L -eq '--restart') {$RESTART = '--restart'}
        if ($L -eq '--status') {$STATUS = '--status'}
        if ($L -eq '--clear') {$CLEAR = '--clear'}
        if ($L -eq '--fast') {$FAST = '--fast'}
        if ($L -eq '--force') {$FORCE = '--force'}
        if ($L -eq '--doitnow') {$DOITNOW = '--doitnow'}
        if ($L -eq '--flags') {$FLAGS = '--flags'}
        if ($L -eq '--clearlogs') {$CLEARLOGS = '--clearlogs'}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '-a' -or $L -eq '--a') {$A = 'True'}
        if ($L -eq '-b' -or $L -eq '--b') {$B = 'True'}
        if ($L -eq '--both') {$BOTH = 'True'}
        if ($L -eq '--interface' -or $L -eq '-i') {$INTERFACE = 'True'}

    }

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
if (!$A -and !$B -and !$BOTH -and !$INTERFACE) {Write-Output "No tomcats specified. Please use '-a -b --both --interface'"; exit}
if ($STOP -and $START) {Write-Output "Cannot specify --stop & --start. Please use --restart"; exit}
if ($STOP -and $RESTART) {Write-Output "Cannot specify --stop & --restart. Please use --restart"; exit}
if ($RESTART -and $START) {Write-Output "Cannot specify --restart & --start. Please select one action flag"; exit}
if ($STOP) {$ACTION = 'Stopp'}
if ($START) {$ACTION = 'Start'}
if ($RESTART) {$ACTION = 'Restart'}
if ($STATUS) {$ACTION = 'Check'}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$KEYFILE = "$DRIVE\scripts\sources\secure\ts01_privkey_openssh.key"
$SSH_AUTH =  New-Object System.Management.Automation.PSCredential("root",(New-Object System.Security.SecureString))

#--Determine which tomcats to restart
$APPARRAY = @()
if ($BOTH) {$APPARRAY += $APP1, $APP2}
    else
        {
         if ($A -eq 'True') {$APPARRAY += $APP1}
         if ($B -eq 'True') {$APPARRAY += $APP2}
        }

#--Restart the specified tomcats
foreach ($APP in $APPARRAY)
    {
        #$SSH_SESSION = New-SSHSession -ComputerName $APP -Credential $SSH_AUTH -KeyFile $KEYFILE -AcceptKey
        #$SSH_STREAM = New-SSHShellStream -SessionId $SSH_SESSION.sessionid
        Write-Output "~: $ACTION`ing Site$SID tomcat on $APP"
        #$SSH_STREAM.WriteLine("/scripts/safe_tomcat --site=$SID $START $STOP $RESTART $STATUS $CLEAR $CLEARLOGS $FAST $FORCE $DOITNOW $FLAGS $HELP")
        #$SSH_STREAM.Read()
        #Invoke-SSHCommandStream -SessionId $SSH_SESSION.sessionid -Command "/scripts/safe_tomcat --site=$SID $START $STOP $RESTART $STATUS $CLEAR $CLEARLOGS $FAST $FORCE $DOITNOW $FLAGS $HELP" 
        #Invoke-SSHStreamShellCommand -ShellStream $SSH_STREAM -Command "/scripts/safe_tomcat --site=$SID $START $STOP $RESTART $STATUS $CLEAR $CLEARLOGS $FAST $FORCE $DOITNOW $FLAGS $HELP"
        #$SSH_STREAM.read()
        #$Stream.read()
        #Write-Output "~: Running safe_tomcat on $APP"
        Connect-Ssh -ComputerName $APP -ScriptBlock "/scripts/safe_tomcat --site=$SID $START $STOP $RESTART $STATUS $CLEAR $CLEARLOGS $FAST $FORCE $DOITNOW $FLAGS $HELP;exit"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP /scripts/safe_tomcat --site=$SID $START $STOP $RESTART $STATUS $CLEAR $CLEARLOGS $FAST $FORCE $DOITNOW $FLAGS $HELP
        #Remove-SSHSession -SessionId $SSH_SESSION.sessionid|Out-Null
    }


#--Interface Server options
if ($INTERFACE -eq 'True')
    {
         $LABHOST = $SHOW.a3
         if ($LABHOST -notlike 'lab*'){Write-Host "Interface server was specified, but no interface server was found.";exit}
         if ($RESTART -and !$STOP -and !$START) {$STOP = 'True';$START = 'True'}

         #--Get the tomcat service version and path
         $SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
         $TOMCATVER = $SERVICE.pathname.split('\')[3]
         $SIDPID = $SERVICE.processid
         $WORK = "\\$LABHOST\c$\alley\site$SID\$TOMCATVER\work\catalina"
         $TESTWORK = Test-Path $WORK

         #--Stop the tomcat service and clear the work directory
         if ($STOP)
             {
                Write-Host "Stopping site$SID $TOMCATVER on $LABHOST"
                Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Service -Force $using:SERVICE.name -NoWait}
                Invoke-Command -ComputerName $LABHOST -ScriptBlock {Stop-Process -id $using:SIDPID -Force -ErrorAction SilentlyContinue}
                if ($CLEAR)
                    {
                        Write-Host "Clearing work directory"
                        if ($TESTWORK -eq $TRUE){Remove-Item -Force -Recurse $WORK}
                    }
             }

         #--Start the tomcat service and run CheckDB
         if ($START)
            {
                Invoke-Command -ComputerName $LABHOST -ScriptBlock {Start-Service $using:SERVICE.name}
                CheckDB --site=$SID --timeout
            }

         #--CheckDB
         if ($STATUS)
             {
                CheckDB --site=$SID --timeout
            }
    }