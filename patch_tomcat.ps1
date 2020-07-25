#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
$HOSTNAME = hostname

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
            if ($L -eq '-p' -or $L -eq '--patch'){$PATCH = $R}
            if ($L -eq '--interface' -or $L -eq '-i') {$m_INTERFACE = 'True'}
            if ($L -eq '--app' -or $L -eq '--both') {$APPSERVER = 'True'}
            if ($L -eq '-a') {$m_A = 'True'}
            if ($L -eq '-b') {$m_B = 'True'}
            if ($L -eq '--replace') {$REPLACE = 'True'}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}
            if ($L -eq '--usefiles') {$USEFILES = $TRUE}
            if ($L -eq '--nostart') {$NOSTART = $TRUE}
            if ($L -eq '--skip-restart') {$SKIPRESTART = $TRUE}
    }


#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        '-h|--help' = 'display available options'
        '-s|--site' = 'apply patch for only a specific site'
        '-p|--patch' = 'set patch number'
        '-y|--proceed' = 'proceed without confirming'
        '-i|--interface' = 'specify interface tomcat'
        '--app|--both' = 'specify both application tomcats'
        '-a' = 'specify tomcat A'
        '-b' = 'specify tomcat B'
        '--replace' = 'update zip file on interface server from source'
        '--nostart' = 'do not start the tomcats after the patch is complete'
        '--skip-restart' = 'skips stopping and starting the tomcat(s) as part of the patch proces. some aspects of the patch may not apply until the tomcats are restarted'
                        } | Format-list;exit
    }


#--Test and confirm variables
If (!$m_SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
If (!$m_INTERFACE -and !$APPSERVER -and !$m_A -and !$m_B){Write-Host "No tomcats specified. Please use --interface or --app";exit}
If (!$PATCH) {Write-Host "Please specify a patch number with -p= or --patch=";exit}
If ($APPSERVER -and $m_A -or $APPSERVER -and $m_B) {Write-Host "--app encompasses both application tomcats. Please specify --app or -a/-b";exit}

#--Get tomcat server hostnames
$SHOW = Show-Site --site=$m_SID --tool
#$m_APPCID = $SHOW.app_cluster_id[0]
#$m_APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $m_APPCID;"
$m_APP1 = $SHOW.a1
$m_APP2 = $SHOW.a2
$KEYFILE = "$DRIVE\scripts\sources\secure\ts01_privkey_openssh.key"
$SSH_AUTH =  New-Object System.Management.Automation.PSCredential("root",(New-Object System.Security.SecureString))
if ($m_INTERFACE) 
    {
        $LABHOST = $SHOW.a3
        #Write-Output "debug: $LABHOST"
        if ($LABHOST -notlike '*lab*'){Write-Host "Interface Server may not exist. Please verify and update sitetab if incorrect"; exit}
    }
if ($APPSERVER -or $m_A -or $m_B)
    {
     $APPSERVERS = @()
     if ($APPSERVER){$APPSERVERS += $m_APP1,$m_APP2; $m_A = 'True';$m_B = 'True'}
        else
            {
                if ($m_A) {$APPSERVERS += $m_APP1}
                if ($m_B) {$APPSERVERS += $m_APP2}
            }

    }

#--Get tomcat directory
if ($LABHOST -like 'lab*')
    {   
        $SERVICE = gwmi -ComputerName $LABHOST win32_service|?{$_.Name -eq "$m_SID"}|select name, displayname, startmode, state, pathname, processid
        $LABTOMCATDIR = $SERVICE.pathname.split('\')[3] 
        #$APPCID = $SHOW.app_cluster_id[0]
        #$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        #$m_APP1 = $APPID.a1  
        #if (Test-Path \\$LABHOST\c$\alley\site$m_SID\tomcat7) { $LABTOMCATDIR = 'tomcat7' }
        #else { $LABTOMCATDIR = 'tomcat6' }
        #Write-Host "DEBUG - $SERVICE"
        #--Define URL's for checking version
        $VER_URL = '/mobiledoc/jsp/catalog/xml/CheckServerVersion.jsp'
        $m_APP1_TOMCAT = "$m_APP1`:3$m_SID"
        $APP3_TOMCAT = "$LABHOST`:3$m_SID"
        #Write-Host "Debug:http://$m_APP1_TOMCAT$VER_URL"
        #Write-Host "Debug:http://$APP3_TOMCAT$VER_URL"
        $m_APP1_VERSION = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 3 http://$m_APP1_TOMCAT$VER_URL
        $APP3_VERSION = Invoke-WebRequest -ErrorAction SilentlyContinue  -TimeoutSec 5 http://$APP3_TOMCAT$VER_URL

        

        <#--Check if xerces.jar exists and needs to be deleted
        $XERCES1 = Test-Path -Path \\$LABHOST\c$\alley\site$m_SID\$LABTOMCATDIR\webapps\mobiledoc\WEB-INF\lib\xerces.jar*
        $XERCES2 = Test-Path -Path \\$LABHOST\c$\alley\site$m_SID\$LABTOMCATDIR\webapps\mobiledoc\WEB-INF\lib\backup\xerces.jar*
        if ($m_APP1_VERSION -like 'SP2' -or $m_APP1_VERSION -like 'V11' -and $APP3_VERSION -notlike 'SP2' -or $APP3_VERSION -notlike 'V11' -and $XERCES1 -eq $TRUE -or $XERCES2 -eq $TRUE)
            {$DELXERCES = $TRUE}#>
    }

if ($APPSERVER -or $m_A -or $m_B)
    {
        if (Test-Path \\$m_APP1\site$m_SID\tomcat8) { $APP1TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$m_APP1\site$m_SID\tomcat7) { $APP1TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$m_APP1\site$m_SID\tomcat6) { $APP1TOMCATDIR = 'tomcat6' }
                        }
                }
        if (Test-Path \\$m_APP2\site$m_SID\tomcat8) { $APP2TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$m_APP2\site$m_SID\tomcat7) { $APP2TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$m_APP2\site$m_SID\tomcat6) { $APP2TOMCATDIR = 'tomcat6' }
                        }
                }
    }

#--Get source patch directory
if ($HOSTNAME -like 'mgt0*')
    {
        $PATCHES_DIR = "M:\scripts\PatchCentral\patches\patch_$PATCH"
    }
if ($HOSTNAME -like 'patch*')
    {
        $P_TMP = 'c:\eClinicalWorks\_patch_archive\'
        $P_TMP1 = Get-ChildItem -Path $P_TMP -Filter $PATCH*
        $PATCHES_DIR = $P_TMP1[-1]
    }

#--Get the Server.zip file
$PATCHZIP = Get-ChildItem -Path $PATCHES_DIR -Name *server.zip
if (!$PATCHZIP -and !$USEFILES){Write-Host "Server zip file not found, exiting.";exit}

#--Check if Server.zip file exists on target Labhost
if ($m_INTERFACE)
    {
        write-host -NoNewline "Copying in or updating server.zip on $LABHOST... "
        $LABPATCHDIR = "\scripts\PatchCentral\patches\patch_$PATCH"
        $LPDTEST = Test-Path \\$LABHOST\c$\$LABPATCHDIR
        if ( $LPDTEST -eq $FALSE)
            {
                md \\$LABHOST\c$\$LABPATCHDIR
            }
        $LPDZIPTEST = Test-Path \\$LABHOST\c$\$LABPATCHDIR\*server.zip
        $LPFZIPTEST = gci \\$LABHOST\c$\$LABPATCHDIR\*server.zip
        if ($LPFZIPTEST.Length -ne $PATCHZIP.Length)
            {
                $REPLACE = $TRUE
            }

        if ( $LPDZIPTEST -eq $FALSE -or $REPLACE)
            {
                cpi $PATCHES_DIR\$PATCHZIP \\$LABHOST\c$\$LABPATCHDIR\
            }
        write-host "Done"
    }



[PSCustomObject] @{
'siteid' = "$m_SID"
'patch' = "$PATCH"
#'Current Version' = "$APP3_VERSION"
#'Target Version' = "$m_APP1_VERSION"
'patch path' = "$PATCHES_DIR\$PATCHZIP"
#'Xerces.jar Deletion' = "$DELXERCES"
'Interface Upgrade' = "$m_INTERFACE"
'APP Server Upgrade' = "$APPSERVER"
'Interface Server' = "$LABHOST, $LABTOMCATDIR"
'APP Servers' = "$m_APP1, $m_APP2, $APPTOMCATDIR"
'Zip File' = "$PATCHZIP"
        }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting upgrade..."}
#Write-Host "Apply patch $PATCH to specified tomcats for site$m_SID`?"
#Write-host -NoNewline "Enter 'PROCEED' to continue: "
#$RESPONSE = read-host
#if ($RESPONSE -cne 'PROCEED') {exit}

#--Perform update on interface server tomcat
if ($LABHOST)
    {
        #--Stop the interface tomcat
        if (!$SKIPRESTART)
            {
                safe_tomcat --site=$m_SID --interface --stop --clear
            }

        #--Unzip to the tomcat folder
        Invoke-Command -ComputerName $LABHOST -ScriptBlock {& "c:\program files\7-zip\7z.exe" x "c:$using:LABPATCHDIR\$using:PATCHZIP" -oC:\alley\site$using:m_SID\$using:LABTOMCATDIR\ -y}
        apu_filemanagement.ps1 --site=$m_SID -i
        if ($DELXERCES)
            {
                if ($XERCES1)
                    {
                        Write-Host "Removing Xerces.jar"
                        Remove-Item -Force \\$LABHOST\c$\alley\site$m_SID\$LABTOMCATDIR\webapps\mobiledoc\WEB-INF\lib\xerces.jar*
                    }
                if ($XERCES2)
                    {
                        Write-Host "Removing backup Xerces.jar"
                        remove-item -force \\$LABHOST\c$\alley\site$m_SID\$LABTOMCATDIR\webapps\mobiledoc\WEB-INF\lib\backup\xerces.jar*
                    }
                
            }
        #--Remove zip file
        Remove-Item -Force \\$LABHOST\c$\$LABPATCHDIR\$PATCHZIP
        $TESTLAB2 = Test-Path \\$LABHOST\c$\$LABPATCHDIR\$PATCHZIP
        if ($TESTLAB2 -eq $false)
            {Write-Host "$PATCHZIP deleted."}
                else
                    {Write-Host "$PATCHZIP not deleted. Please remove \\$LABHOST\c$\$LABPATCHDIR\$PATCHZIP"}
                            

        #--Start the interface tomcat
        If (!$NOSTART -and !$SKIPRESTART)
            {
                safe_tomcat --site=$m_SID --interface --start
            }

    }

#--Copy Server.zip file to application server(s)
if ($APPSERVERS)
    {
        <#foreach ($m_APP in $APPSERVERS)
            {
                Write-Host -NoNewline "Copying $PATCHZIP to \\$m_APP\site$m_SID\$APPTOMCATDIR\..."
                cpi -force $PATCHES_DIR\$PATCHZIP \\$m_APP\site$m_SID\$APPTOMCATDIR\
                Write-Host " Done"
            }#>
        #--Stop the tomcats, unzip the patch file, setperms, restart
        if ($m_A)
            {
                $A_COPY_FAIL = $FALSE
                :A_COPY_FAIL while ($A_COPY_FAIL -eq $FALSE)
                    {
                        if (!$USEFILES)
                            {
                                #--Test SMB
                                if (Test-Path \\$m_APP1\site$m_SID\$APP1TOMCATDIR)
                                    {
                                        $A_USESMB = $TRUE
                                        Write-Output "Copying $PATCHZIP to \\$m_APP1\site$m_SID\$APP1TOMCATDIR\ using SMB..."
                                    }
                                        else
                                            {
                                                #--Test SCP
                                                Send-scp -ComputerName "$m_APP1" -LocalFile $DRIVE\scripts\PatchCentral\utils\sources\permissions_test.txt -RemotePath "/alley/site$m_SID/$APP1TOMCATDIR/"
                                                if (connect-ssh -computername $m_APP1 "ls /alley/site$m_SID/$APP1TOMCATDIR/permissions_test.txt")
                                                    {
                                                        $A_USE_SCP = $TRUE
                                                        Write-Output "Copying $PATCHZIP to \\$m_APP1\site$m_SID\$APP1TOMCATDIR\ using SCP..."
                                                    }
                                                        else
                                                            {
                                                                #--Test pscp
                                                                pscp.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk "$DRIVE\scripts\PatchCentral\utils\sources\permissions_test.txt root@$m_APP1" "/alley/site$m_SID/$APP1TOMCATDIR/"
                                                                if (plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk "ls /alley/site$m_SID/$APP1TOMCATDIR/permissions_test.txt")
                                                                    {
                                                                        $A_USEPLINK = $TRUE
                                                                        Write-Output "Copying $PATCHZIP to \\$m_APP1\site$m_SID\$APP1TOMCATDIR\ using plink..."
                                                                    }
                                                            }
                                            }
                                #--if all tests failed, break out of patching this tomcat
                                if (!$A_USESMB -and !$A_USE_SCP-and !$A_USEPLINK)
                                    {
                                        Write-Output "Permissions test to $m_APP1 failed. Exiting patch attempt for Tomcat A"
                                        $A_COPY_FAIL = $TRUE
                                    }
                                if ($A_COPY_FAIL -eq $TRUE)
                                    {
                                        break A_COPY_FAIL
                                    }
                                
                                #--Get copy start time for status
                                $COPY_A_START = Get-Date
                                #--Copy server.zip file using SMB if true
                                if ($A_USESMB -eq $TRUE)
                                    {
                                        cpi $PATCHES_DIR\$PATCHZIP \\$m_APP1\site$m_SID\$APP1TOMCATDIR\
                                        if ((gci $PATCHES_DIR\$PATCHZIP).Length -eq (gci \\$m_APP1\site$m_SID\$APP1TOMCATDIR\$PATCHZIP).length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :A_COPY_FAIL
                                                    }
                                    }
                                #--Copy server.zip file using SCP if true
                                if ($A_USE_SCP -eq $TRUE)
                                    {
                                        Send-scp -ComputerName $m_APP1 -LocalFile $PATCHES_DIR\$PATCHZIP  -RemotePath "/alley/site$m_SID/$APP1TOMCATDIR/"
                                        if ((connect-ssh -computername $m_APP1 "ls -al /alley/site$m_SID/$APP1TOMCATDIR/$PATCHZIP|awk '{print $5}'") -eq (gci $PATCHES_DIR\$PATCHZIP).Length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :A_COPY_FAIL
                                                    }
                                    }
                                #--Copy server.zip file using PSCP if true
                                if ($A_USEPLINK -eq $TRUE)
                                    {
                                        pscp.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk $PATCHES_DIR\$PATCHZIP  root@$m_APP1`:/alley/site$m_SID/$APP1TOMCATDIR/
                                        if ((plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP1 "ls -al /alley/site$m_SID/$APP1TOMCATDIR/$PATCHZIP|awk '{print $5}'") -eq (gci $PATCHES_DIR\$PATCHZIP).Length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :A_COPY_FAIL
                                                    }
                                    }
                                
                                #--Calculate duration
                                $COPY_A_END = Get-Date
                                $COPY_A_TIME = [math]::round((($COPY_A_END) - ($COPY_A_START)).totalseconds)
                                Write-Output "Copying $PATCHZIP took $COPY_A_TIME seconds"
                                #cpi -force $PATCHES_DIR\$PATCHZIP \\$m_APP1\site$m_SID\$APP1TOMCATDIR\
                                #--Stop tomcat prior to unzip
                                if (!$SKIPRESTART)
                                    {
                                        safe_tomcat --site=$m_SID --a --stop --clear --fast --force
                                    }
                                #setperms --site=$m_SID --a --unlock
                                #--Get zip start time for status
                                $ZIP_A_START = Get-Date
                                #--Unzip server.zip file
                                Connect-Ssh -ComputerName $m_APP1 -ScriptBlock "cd /alley/site$m_SID/$APP1TOMCATDIR/;7za x $PATCHZIP -y"
                                #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP1 "cd /alley/site$m_SID/$APP1TOMCATDIR/;7za x $PATCHZIP -y"
                                #--Calculate zip duration
                                $ZIP_A_END = Get-Date
                                $ZIP_A_TIME = [math]::round((($ZIP_A_END) - ($ZIP_A_START)).totalseconds)
                                Write-Output "Unzipping $PATCHZIP took $ZIP_A_TIME seconds"
                                #--Set tomcat permissions
                                setperms --site=$m_SID --a
                                #--Run apu_filemanagement to clean up old jar files
                                apu_filemanagement.ps1 --site=$m_SID '-a'
                                #--Start the tomcat                        
                                if (!$NOSTART -and !$SKIPRESTART)
                                    {
                                        safe_tomcat --site=$m_SID --a --start
                                    }
                                #--Remove the server.zip file
                                Write-Host -NoNewline "Removing $PATCHZIP from \\$m_APP1\site$m_SID\$APP1TOMCATDIR\..."
                                Connect-Ssh -ComputerName $m_APP1 -ScriptBlock "cd /alley/site$m_SID/$APP1TOMCATDIR/;rm -f $PATCHZIP"
                                #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP1 "cd /alley/site$m_SID/$APP1TOMCATDIR/;rm -f $PATCHZIP"
                                Write-Host " Done"
                            }
                                else
                                    {
                                        if (!$SKIPRESTART)
                                            {
                                                safe_tomcat --site=$m_SID --a --stop --clear --fast --force
                                            }
                                        setperms --site=$m_SID --a --unlock
                                        Write-Host -NoNewline "Copying $PATCHES_DIR\server\webapps to \\$m_APP1\site$m_SID\$APP2TOMCATDIR\..."
                                        cpi -force -Recurse $PATCHES_DIR\server\webapps \\$m_APP1\site$m_SID\$APP1TOMCATDIR\
                                        Write-Host " Done"
                                        apu_filemanagement.ps1 --site=$m_SID '-a'
                                        setperms --site=$m_SID --a
                                        if (!$NOSTART -and !$SKIPRESTART)
                                            {
                                                safe_tomcat --site=$m_SID --a --start
                                            }
                                    }
                    #--if you got this far, it was as successful as it was going to get, and we can break out of loop now
                    Write-Output "Patch_$PATCH process complete on $m_APP1"
                    break A_COPY_FAIL
                }
            }
        if ($m_B)
            {
                $B_COPY_FAIL = $FALSE
                :B_COPY_FAIL while ($B_COPY_FAIL -eq $FALSE)
                    {
                        if (!$USEFILES)
                            {
                                #--Test SMB
                                if (Test-Path \\$m_APP2\site$m_SID\$APP2TOMCATDIR)
                                    {
                                        $B_USESMB = $TRUE
                                        Write-Output "Copying $PATCHZIP to \\$m_APP2\site$m_SID\$APP2TOMCATDIR\ using SMB..."
                                    }
                                        else
                                            {
                                                #--Test SCP
                                                Send-scp -ComputerName "$m_APP2" -LocalFile $DRIVE\scripts\PatchCentral\utils\sources\permissions_test.txt -RemotePath "/alley/site$m_SID/$APP2TOMCATDIR/"
                                                if (connect-ssh -computername $m_APP2 "ls /alley/site$m_SID/$APP2TOMCATDIR/permissions_test.txt")
                                                    {
                                                        $B_USE_SCP = $TRUE
                                                        Write-Output "Copying $PATCHZIP to \\$m_APP2\site$m_SID\$APP2TOMCATDIR\ using SCP..."
                                                    }
                                                        else
                                                            {
                                                                #--Test pscp
                                                                pscp.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk "$DRIVE\scripts\PatchCentral\utils\sources\permissions_test.txt root@$m_APP2" "/alley/site$m_SID/$APP2TOMCATDIR/"
                                                                if (plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk "ls /alley/site$m_SID/$APP2TOMCATDIR/permissions_test.txt")
                                                                    {
                                                                        $B_USEPLINK = $TRUE
                                                                        Write-Output "Copying $PATCHZIP to \\$m_APP2\site$m_SID\$APP2TOMCATDIR\ using plink..."
                                                                    }
                                                            }
                                            }
                                #--if all tests failed, break out of patching this tomcat
                                if (!$B_USESMB -and !$B_USE_SCP -and !$B_USEPLINK)
                                    {
                                        Write-Output "Permissions test to $m_APP2 failed. Exiting patch attempt for Tomcat B"
                                        $B_COPY_FAIL = $TRUE
                                    }
                                if ($B_COPY_FAIL -eq $TRUE)
                                    {
                                        break A_COPY_FAIL
                                    }
                                
                                #--Get copy start time for status
                                $COPY_B_START = Get-Date
                                #--Copy server.zip file using SMB if true
                                if ($B_USESMB -eq $TRUE)
                                    {
                                        cpi $PATCHES_DIR\$PATCHZIP \\$m_APP2\site$m_SID\$APP2TOMCATDIR\
                                        if ((gci $PATCHES_DIR\$PATCHZIP).Length -eq (gci \\$m_APP2\site$m_SID\$APP2TOMCATDIR\$PATCHZIP).length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :B_COPY_FAIL
                                                    }
                                    }
                                #--Copy server.zip file using SCP if true
                                if ($B_USE_SCP -eq $TRUE)
                                    {
                                        Send-scp -ComputerName $m_APP2 -LocalFile $PATCHES_DIR\$PATCHZIP  -RemotePath "/alley/site$m_SID/$APP2TOMCATDIR/"
                                        if ((connect-ssh -computername $m_APP2 "ls -al /alley/site$m_SID/$APP2TOMCATDIR/$PATCHZIP|awk '{print $5}'") -eq (gci $PATCHES_DIR\$PATCHZIP).Length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :B_COPY_FAIL
                                                    }
                                    }
                                #--Copy server.zip file using PSCP if true
                                if ($B_USEPLINK -eq $TRUE)
                                    {
                                        pscp.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk $PATCHES_DIR\$PATCHZIP  root@$m_APP2`:/alley/site$m_SID/$APP2TOMCATDIR/
                                        if ((plink.exe -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP2 "ls -al /alley/site$m_SID/$APP2TOMCATDIR/$PATCHZIP|awk '{print $5}'") -eq (gci $PATCHES_DIR\$PATCHZIP).Length)
                                            {
                                                Write-Output "Zip copy succeeded"
                                            }
                                                else
                                                    {
                                                        Write-Output "Zip copy failed"
                                                        break :B_COPY_FAIL
                                                    }
                                    }
                                
                                #--Calculate duration
                                $COPY_B_END = Get-Date
                                $COPY_B_TIME = [math]::round((($COPY_B_END) - ($COPY_B_START)).totalseconds)
                                Write-Output "Copying $PATCHZIP took $COPY_B_TIME seconds"
                                #cpi -force $PATCHES_DIR\$PATCHZIP \\$m_APP2\site$m_SID\$APP2TOMCATDIR\
                                #--Stop tomcat prior to unzip
                                if (!$SKIPRESTART)
                                    {
                                        safe_tomcat --site=$m_SID --b --stop --clear --fast --force
                                    }
                                #setperms --site=$m_SID --a --unlock
                                #--Get zip start time for status
                                $ZIP_B_START = Get-Date
                                #--Unzip server.zip file
                                Connect-Ssh -ComputerName $m_APP2 -ScriptBlock "cd /alley/site$m_SID/$APP2TOMCATDIR/;7za x $PATCHZIP -y"
                                #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP2 "cd /alley/site$m_SID/$APP2TOMCATDIR/;7za x $PATCHZIP -y"
                                #--Calculate zip duration
                                $ZIP_B_END = Get-Date
                                $ZIP_B_TIME = [math]::round((($ZIP_B_END) - ($ZIP_B_START)).totalseconds)
                                Write-Output "Unzipping $PATCHZIP took $ZIP_B_TIME seconds"
                                #--Set tomcat permissions
                                setperms --site=$m_SID --b
                                #--Run apu_filemanagement to clean up old jar files
                                apu_filemanagement.ps1 --site=$m_SID '-b'
                                #--Start the tomcat                        
                                if (!$NOSTART -and !$SKIPRESTART)
                                    {
                                        safe_tomcat --site=$m_SID --b --start
                                    }
                                #--Remove the server.zip file
                                Write-Host -NoNewline "Removing $PATCHZIP from \\$m_APP2\site$m_SID\$APP2TOMCATDIR\..."
                                Connect-Ssh -ComputerName $m_APP2 -ScriptBlock "cd /alley/site$m_SID/$APP2TOMCATDIR/;rm -f $PATCHZIP"
                                #plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$m_APP2 "cd /alley/site$m_SID/$APP2TOMCATDIR/;rm -f $PATCHZIP"
                                Write-Host " Done"
                            }
                                else
                                    {
                                        if (!$SKIPRESTART)
                                            {
                                                safe_tomcat --site=$m_SID --b --stop --clear --fast --force
                                            }
                                        setperms --site=$m_SID --b --unlock
                                        Write-Host -NoNewline "Copying $PATCHES_DIR\server\webapps to \\$m_APP2\site$m_SID\$APP2TOMCATDIR\..."
                                        cpi -force -Recurse $PATCHES_DIR\server\webapps \\$m_APP2\site$m_SID\$APP2TOMCATDIR\
                                        Write-Host " Done"
                                        apu_filemanagement.ps1 --site=$m_SID '-b'
                                        setperms --site=$m_SID --b
                                        if (!$NOSTART -and !$SKIPRESTART)
                                            {
                                                safe_tomcat --site=$m_SID --b --start
                                            }
                                    }
                    #--if you got this far, it was as successful as it was going to get, and we can break out of loop now
                    Write-Output "Patch_$PATCH process complete on $m_APP2"
                    break B_COPY_FAIL
                }
            }
    }