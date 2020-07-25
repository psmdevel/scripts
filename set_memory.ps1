#--Set Tomcat Memory on linux tomcat servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = 'True'}
        if ($L -eq '--min') {$MIN = $R}
        if ($L -eq '--max') {$MAX = $R}
        if ($L -eq '--bump') {$BUMP = '--bump'}
        if ($L -eq '--bumpmin') {$BUMPMIN = '--bumpmin'}
        if ($L -eq '--bumpmax') {$BUMPMAX = '--bumpmax'}
        if ($L -eq '-c' -or $L -eq '--check') {$CHECK = '--check'}
        if ($L -eq '--restart') {$m_RESTART = 'True'} 
        if ($L -eq '--clearlogs') {$CLEARLOGS = '--clearlogs'}
        if ($L -eq '-y' -or $L -eq '--proceed') {$PROCEED = '--proceed'}   
    }

#--Display available options
if ($HELP -eq 'True')
{
[PSCustomObject] @{
'-s|--site' = 'specify the site number'
'-h|--help' = 'display available options'
'-c|--check' = 'check current memory allocation'
'--min=' = 'set minimum memory'
'--max=' = 'set maximum memory'
'--bumpmin' = 'bump minimum memory'
'--bumpmax' = 'bump maximum memory'
'--bump' = 'bump both minimum & maximum memory'
'--restart' = 'restarts both tomcats without a catalina clear'
'--clearlogs' = 'clears tomcat logs during restart'
'-y|--proceed' = 'required to commit specifed changes'
} | Format-list;exit
}

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
if ($MAX -and $BUMPMAX) {Write-Output "Please use only --min/--max or --bumpmin/--bumpmax";exit}
if ($MIN -and $BUMPMIN) {Write-Output "Please use only --min/--max or --bumpmin/--bumpmax";exit}
if ($MIN -and $BUMPMAX) {Write-Output "Please use only --min/--max or --bumpmin/--bumpmax";exit}
if ($MAX -and $BUMPMIN) {Write-Output "Please use only --min/--max or --bumpmin/--bumpmax";exit}
if (!$MIN -and !$MAX -and !$BUMPMIN -and !$BUMPMAX -and !$BUMP) {$CHECK = '--check'}
if (!$m_RESTART -and $CLEARLOGS) {Write-Output "--clearlogs must be used with --restart";exit}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

        if (Test-Path \\$APP1\site$SID\tomcat8) { $APP1TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$SID\tomcat7) { $APP1TOMCATDIR = 'tomcat7' }
                        else 
                            {
                                if (Test-Path \\$APP1\site$SID\tomcat6) { $APP1TOMCATDIR = 'tomcat6' }
                            }
                }
        if (Test-Path \\$APP2\site$SID\tomcat8) { $APP2TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP2\site$SID\tomcat7) { $APP2TOMCATDIR = 'tomcat7' }
                        else 
                            {
                                if (Test-Path \\$APP2\site$SID\tomcat6) { $APP2TOMCATDIR = 'tomcat6' }
                            }
                }

#--Bump the minimum memory, maximum memory, or both, and copy the tomcat-env.sh file to the other tomcat
if ($BUMPMIN -or $BUMPMAX -or $BUMP)
    {
        
         Connect-Ssh -ComputerName $APP1 -ScriptBlock "/scripts/set_memory --site=$SID $BUMPMIN $BUMPMAX $BUMP $PROCEED; exit"
         Connect-Ssh -ComputerName $APP2 -ScriptBlock "/scripts/set_memory --site=$SID $BUMPMIN $BUMPMAX $BUMP $PROCEED; exit"
         #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 /scripts/set_memory --site=$SID $BUMPMIN $BUMPMAX $BUMP $PROCEED; exit
         #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 /scripts/set_memory --site=$SID $BUMPMIN $BUMPMAX $BUMP $PROCEED; exit
         #Write-Output "Copying tomcat-env.sh to Tomcat B"
         #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$TOMCATDIR/conf;rsync -avh tomcat-env.sh $APP2`:`$PWD"
    }

#--Check current memory allocation
if ($CHECK)
    {
        Write-Host "~: Tomcat_A on $APP1`:"
        Connect-Ssh -ComputerName $APP1 -ScriptBlock "/scripts/set_memory --site=$SID $CHECK"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 /scripts/set_memory --site=$SID $CHECK
        Write-Host "~: Tomcat_B on $APP2`:"
        Connect-Ssh -ComputerName $APP2 -ScriptBlock "/scripts/set_memory --site=$SID $CHECK"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 /scripts/set_memory --site=$SID $CHECK
    }

#--Set minimum and/or maximum memory to a specified value, and copy the tomcat-env.sh file to the other tomcat
if ($MIN -and $MAX)
    {
        Connect-Ssh -ComputerName $APP1 -ScriptBlock "/scripts/set_memory --site=$SID --min=$MIN --max=$MAX $PROCEED; exit"
        Connect-Ssh -ComputerName $APP2 -ScriptBlock "/scripts/set_memory --site=$SID --min=$MIN --max=$MAX $PROCEED; exit"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 /scripts/set_memory --site=$SID --min=$MIN --max=$MAX $PROCEED; exit
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 /scripts/set_memory --site=$SID --min=$MIN --max=$MAX $PROCEED; exit
        #Write-Output "Copying tomcat-env.sh to Tomcat B"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$TOMCATDIR/conf;rsync -avh tomcat-env.sh $APP2`:`$PWD"
    }

if ($MIN -and !$MAX)
    {
        Connect-Ssh -ComputerName $APP1 -ScriptBlock "/scripts/set_memory --site=$SID --min=$MIN $PROCEED; exit"
        Connect-Ssh -ComputerName $APP2 -ScriptBlock "/scripts/set_memory --site=$SID --min=$MIN $PROCEED; exit"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 /scripts/set_memory --site=$SID --min=$MIN $PROCEED; exit
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 /scripts/set_memory --site=$SID --min=$MIN $PROCEED; exit
        #Write-Output "Copying tomcat-env.sh to Tomcat B"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$TOMCATDIR/conf;rsync -avh tomcat-env.sh $APP2`:`$PWD"
    }

if (!$MIN -and $MAX)
    {
        Connect-Ssh -ComputerName $APP1 -ScriptBlock "/scripts/set_memory --site=$SID --max=$MAX $PROCEED; exit"
        Connect-Ssh -ComputerName $APP2 -ScriptBlock "/scripts/set_memory --site=$SID --max=$MAX $PROCEED; exit"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 /scripts/set_memory --site=$SID --max=$MAX $PROCEED; exit
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 /scripts/set_memory --site=$SID --max=$MAX $PROCEED; exit
        #Write-Output "Copying tomcat-env.sh to Tomcat B"
        #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$TOMCATDIR/conf;rsync -avh tomcat-env.sh $APP2`:`$PWD"
    }

#--Restart the tomcats, clearing the logs if specified
if ($m_RESTART)
    {
        safe_tomcat --site=$SID --restart --fast --both $CLEARLOGS
    }