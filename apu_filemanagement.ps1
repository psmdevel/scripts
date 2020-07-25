<#--Apu File Management

    Queries the apufilemanagement table and checks the tomcats for the filetolookfor and filetodelete entries and acts accordingly
#>

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
Import-Module SimplySql

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '-a') {$A = $TRUE}
        if ($L -eq '-b') {$B = $TRUE}
        if ($L -eq '-i' -or $L -eq '--interface'){$INTERFACE = $true}
        if ($L -eq '--both') {$BOTH = $TRUE}
        if ($L -eq '--whatif') {$WHATIF = '-WhatIf'}
        if ($L -eq '--usescript') {$USESCRIPT = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Queries the apufilemanagement table and checks the tomcats for old files to delete and acts accordingly"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'-a|-b|--both|-i' = "Runs script against specified tomcats"
'--whatif' = "Shows files to delete but makes no changes. Does not work with --usescript"
'--usescript' = "Uses the Linux version of this script on specified Linux tomcat servers"
                }|Format-List; exit
            }

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
If (!$A -and !$B -and !$BOTH -and !$INTERFACE){Write-Host "Please specify which tomcats to check using: -a, -b, -i, or --both"}

#--Get the site information from ControlData
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site$SID`_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$Auth_SID = $SHOW.auth_sid

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2


#--Determine the tomcats to set permissions
$APPARRAY = @()
if ($BOTH) 
    {
        $A = $TRUE
        $B = $TRUE
    }
        else
            {
                if ($A) {$APPARRAY += $APP1}
                if ($B) {$APPARRAY += $APP2}
            }

if ($A -or $B)
    {
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
    }

if ($INTERFACE)
    {
        $LABHOST = $SHOW.a3
        if ($LABHOST -notlike '*lab*')
            {
                Write-Host "Interface server specified, but server is not found. Exiting."
                exit;
            }
        $SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
        $LABTOMCATDIR = $SERVICE.pathname.split('\')[3]
    }
if ($USESCRIPT)
    {
        if ($A)
            {
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "/scripts/apufilemanage --site=$SID"
            }

        if ($B)
            {
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 "/scripts/apufilemanage --site=$SID"
            };exit
    }

#--Get the apufilemanagement table contents
Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Credential $Auth_SID -Database mobiledoc_$SID
$AFMARRAY = Invoke-SqlQuery -Query "select * from apufilemanagement where deleteflag = 0 order by id;"
#$AFMARRAY = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from apufilemanagement where deleteflag = 0 order by id;"
Close-SqlConnection

if ($A)
    {
        Write-Output "running apu_filemanagement on $APP1 for site$SID"
        if (-not(Test-Path \\$APP1\\site$SID\$APP1TOMCATDIR))
            {
                Write-Output "Could not access $APP1TOMCATDIR on $APP1, apu_filemanagement [FAILED], exiting"
                exit
            }
    }
if ($B)
    {
        Write-Output "running apu_filemanagement on $APP2 for site$SID"
        if (-not(Test-Path \\$APP2\site$SID\$APP2TOMCATDIR))
            {
                Write-Output "Could not access $APP2TOMCATDIR on $APP1, apu_filemanagement [FAILED], exiting"
                exit
            }
    }
if ($INTERFACE)
    {
        Write-Output "running apu_filemanagement on $LABHOST for site$SID"
        if (-not(Test-Path \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR))
            {
                Write-Output "Could not access $LABTOMCATDIR on $LABHOST, apu_filemanagement [FAILED], exiting"
                exit
            }
    }
    foreach ($AFMSET in $AFMARRAY)
        {
            $AFMLOOK = $AFMSET.filetolookfor
            $AFMLOOK = $AFMLOOK.TrimStart('/')
            $AFMLOOK = $AFMLOOK.Replace('/','\')
            $AFMDEL = $AFMSET.fileorfoldertodelete
            $AFMDEL = $AFMDEL.TrimStart('/')
            $AFMDEL = $AFMDEL.Replace('/','\')
            if ($A)
                {
                    $AFMLOOKTEST = Test-Path \\$APP1\site$SID\$APP1TOMCATDIR\webapps\$AFMLOOK -ErrorAction SilentlyContinue
                    $AFMDELTEST = Test-Path \\$APP1\site$SID\$APP1TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                    $AFMLOOKFILE = $AFMLOOK.split('\')[-1]
                    $AFMDELFILE = $AFMDEL.split('\')[-1]
                    if ($AFMLOOKTEST -eq $TRUE -and $AFMDELTEST -eq $TRUE){$AFMDELCONFIRM = $TRUE} else {$AFMDELCONFIRM = $FALSE}
                    if ($AFMDELCONFIRM -eq $TRUE)
                        {
                            Write-Host -NoNewline "$AFMDELFILE to be deleted on $APP1`: [$AFMDELCONFIRM]"
                            if ($WHATIF)
                                {Remove-Item -WhatIf -Force -Recurse \\$APP1\site$SID\$APP1TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue}
                                    else
                                        {Remove-Item -Force -Recurse \\$APP1\site$SID\$APP1TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue}
                            $AFMDELTEST2 = Test-Path \\$APP1\site$SID\$APP1TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                            if ($AFMDELTEST2 -eq $TRUE){Write-Host -ForegroundColor Red '[FAILED]'} else {Write-Host -ForegroundColor Green '[SUCCESS]'}
                        }
                }
            if ($B)
                {
                    $AFMLOOKTEST = Test-Path \\$APP2\site$SID\$APP2TOMCATDIR\webapps\$AFMLOOK -ErrorAction SilentlyContinue
                    $AFMDELTEST = Test-Path \\$APP2\site$SID\$APP2TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                    $AFMLOOKFILE = $AFMLOOK.split('\')[-1]
                    $AFMDELFILE = $AFMDEL.split('\')[-1]
                    if ($AFMLOOKTEST -eq $TRUE -and $AFMDELTEST -eq $TRUE){$AFMDELCONFIRM = $TRUE} else {$AFMDELCONFIRM = $FALSE}
                    if ($AFMDELCONFIRM -eq $TRUE)
                        {
                            Write-Host -NoNewline "$AFMDELFILE to be deleted on $APP2`: [$AFMDELCONFIRM]"
                            if ($WHATIF)
                                {Remove-Item -WhatIf -Force -Recurse \\$APP2\site$SID\$APP2TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue}
                                    else
                                        {Remove-Item -Force -Recurse \\$APP2\site$SID\$APP2TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue}
                            $AFMDELTEST2 = Test-Path \\$APP2\site$SID\$APP2TOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                            if ($AFMDELTEST2 -eq $TRUE){Write-Host -ForegroundColor Red '[FAILED]'} else {Write-Host -ForegroundColor Green '[SUCCESS]'}
                        }
                }
            if ($INTERFACE)
                {
                    $AFMLOOKTEST = Test-Path \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR\webapps\$AFMLOOK -ErrorAction SilentlyContinue
                    $AFMDELTEST = Test-Path \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                    $AFMLOOKFILE = $AFMLOOK.split('\')[-1]
                    $AFMDELFILE = $AFMDEL.split('\')[-1]
                    if ($AFMLOOKTEST -eq $TRUE -and $AFMDELTEST -eq $TRUE){$AFMDELCONFIRM = $TRUE} else {$AFMDELCONFIRM = $FALSE}
                    if ($AFMDELCONFIRM -eq $TRUE)
                        {
                            Write-Host -NoNewline "$AFMDELFILE to be deleted on $LABHOST`: [$AFMDELCONFIRM]"
                            if ($WHATIF)
                                {Remove-Item -WhatIf -Force -Recurse \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR\webapps\$AFMDEL}
                                    else
                                        {Remove-Item -Force -Recurse \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR\webapps\$AFMDEL}                                
                            $AFMDELTEST2 = Test-Path \\$LABHOST\c$\alley\site$SID\$LABTOMCATDIR\webapps\$AFMDEL -ErrorAction SilentlyContinue
                            if ($AFMDELTEST2 -eq $TRUE){Write-Host -ForegroundColor Red '[FAILED]'} else {Write-Host -ForegroundColor Green '[SUCCESS]'}
                            
                        }




                }
            #$AFMLOOKTEST = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$SID/$APP2TOMCATDIR/webapps/; /bin/ls -alt $AFMLOOK"
            #$AFMDELTEST = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$SID/$APP2TOMCATDIR/webapps/; /bin/ls -alt $AFMDEL"
            #if ($AFMLOOKTEST -eq $FALSE){$AFMLOOKFOUND = $FALSE} else {$AFMLOOKFOUND = $TRUE}
            #if ($AFMDELTEST -eq $FALSE){$AFMDELFOUND = $FALSE} else {$AFMDELFOUND = $TRUE}

            #Write-Host "$AFMLOOKFILE[$AFMLOOKTEST]; $AFMDELFILE[$AFMDELTEST]"
            #Write-Host "\\$APP1/site$SID/$APP1TOMCATDIR`webapps$AFMLOOK"
            #Write-Host "\\$APP1/site$SID/$APP1TOMCATDIR`webapps$AFMDEL"

        }