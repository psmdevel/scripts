#--Run JSP's for a specifed patch

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module SimplySql
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        if ($L -eq '--force' -or $L -eq '-f' ){$FORCE = $TRUE}
        if ($L -eq '--allow' -or $L -eq '-a' ){$ALLOW = $TRUE}
        if ($L -eq '--norestart' ){$NORESTART = $TRUE}
    }

#--Get source patch directory
$HOSTNAME = hostname
if ($HOSTNAME -like 'mgt0*')
    {
        if (test-path "M:\scripts\PatchCentral\patches\patch_$PATCH")
            {
                $PATCHES_DIR = "M:\scripts\PatchCentral\patches\patch_$PATCH"
            }
                else
                    {
                        Write-Output "Specified patch not found at M:\scripts\PatchCentral\patches\patch_$PATCH, exiting"
                        exit
                    }
    }
if ($HOSTNAME -like 'patch*')
    {
        $P_TMP = 'c:\eClinicalWorks\_patch_archive\'
        $P_TMP1 = Get-ChildItem -Path $P_TMP -Filter $PATCH*
        $PATCHES_DIR = $P_TMP1[-1]
        if (!$PATCHES_DIR)
            {
                Write-Output "Specified patch not found in c:\eClinicalWorks\_patch_archive\, exiting"
                exit
            }
    }

#--Get the list of JSP's
if (test-path $PATCHES_DIR\server\AutoUpgradeSQLJsp.xml)
    {
        [xml]$JSPLIST = Get-Content $PATCHES_DIR\server\AutoUpgradeSQLJsp.xml
    }
        else
            {
                Write-Output "AutoUpgradeSQLJsp.xml not found for patch $PATCH, exiting"
                exit
            }

#--Get the site info
$SHOW = Show-Site --site=$SID --tool
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$DBPORT = "5$SID"
$Auth_SID = $SHOW.auth_SID
#write-host "DEBUG DbClust: $DBCLUST
#DEBUG DbUser: $DBUSER
#DEBUG DbPwd: $DBPWD
#DEBUG DbPort: $DBPORT
#DEBUG Auth_SID: $Auth_SID"
#--Get tomcat server hostnames
$m_APP1 = $SHOW.a1
$m_APP2 = $SHOW.a2
$APP1_TOMCAT = "$m_APP1`:3$SID"

#--get the JSP's that should be run
$JSPSTORUN = @()

#Open-MySqlConnection -Server $SHOW.db_cluster -Port 5$SID -Database "mobiledoc_$SID" -Credential $SHOW.auth_sid -ConnectionName SQL$SID`_runjsp
foreach ($JSPS in $JSPLIST.queries.query)
    {
        $JSP = $JSPS.'#text'
        $JSPVERSION = $JSPS.version
        $JSPTYPE = $JSPS.versiontype
        #write-host "DEBUG JSP: $JSP"
        #--Check upgrade_sqlversions table to see if the JSP has already been run
        
        $JSPCHECK = Invoke-MySQL -Site $SID -Query "select * from upgrade_sqlversions where version = '$JSPVERSION';"
        
        #$JSPCHECK = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from upgrade_sqlversions where version = '$JSPVERSION';"
        if (!$JSPCHECK -or $FORCE)
            {
                if ($JSP -notlike '*multum_testdummy*')
                    {
                        #Write-Host "Adding $JSPVERSION to list"
                        $JSPSTORUN += $JSPS
                        
                    }
            }
                else
                    {
                        if ($JSP -like '*multum_testdummy*')
                            {
                                Write-Host "JSP is multum_testdummy, skipping"
                            }
                                else
                                    {
                                        if (!$ALLOW)
                                            {
                                                write-host "JSP Version: $JSPVERSION JSP: $JSP - Already run"
                                            }
                                    }
                    }
    }



if ($JSPSTORUN.count -gt 0)
    {
        foreach ($JSPS in $JSPSTORUN)
            {
                $JSP = $JSPS.'#text'
                allow_ecw_sessionless_url.ps1 --site=$SID --url=$JSP|Out-Null
                #write-host "DEBUG: adding $JSP"
                
            }
        #--Only adding jsps to ecw_sessionless_url table, then exit
        if ($ALLOW)
            {
                Write-Output "Allowed $($JSPSTORUN.count) JSP's, exiting"
                exit
            }
        if (!$NORESTART)
            {
                safe_tomcat.ps1 --site=$SID --a --restart --fast
                #write-host "Waiting for tomcat to warmup..."
                #Timeout 30
                do 
                    {
                          Write-Output "Waiting for tomcat to warmup..."
                          sleep 3      
                    } 
                        until
                            (Invoke-WebRequest http://$APP1_TOMCAT/mobiledoc/jsp/catalog/xml/CheckDBConnection.jsp | ? { $_.content -like '*success*' } )
            }
    }
        else
            {
                write-host "No JSP's to run, exiting.";exit
            }



$JSPCOMPLETION = @()
foreach ($JSPS in $JSPSTORUN)
    {
        $JSP = $JSPS.'#text'
        $JSPVERSION = $JSPS.version
        $JSPTYPE = $JSPS.versiontype
        $JSPSTATUSES = New-Object System.Object
        Write-Host "Running $JSP... "
        $RUNJSP = Invoke-WebRequest http://$APP1_TOMCAT$JSP
        
        if ($RUNJSP.content -like "*success*" -or $RUNJSP.content -like '*ok*' -or $RUNJSP.content -like '*complete*')
            {
                $JSPSTATUS = 'Success'
                #--Add JSP info to upgrade_sqlversions
                Invoke-MySQL -Site $SID -Update -Query "insert ignore into upgrade_sqlversions (version,versiontype) values ('$JSPVERSION','$JSPTYPE');"
                #Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="insert ignore into upgrade_sqlversions (version,versiontype) values ('$JSPVERSION','$JSPTYPE');"
            }
        
        if ($RUNJSP.content -like "*fail*" -or $RUNJSP.rawcontent -like '*not*')
            {
                $JSPSTATUS = 'Failed'
            }
        if ($RUNJSP.content -like "*already*")
            {
                $JSPSTATUS = 'PastCompletion'
            }
        
        if ($JSPSTATUS -ne 'Success')
            {
                if ($JSPSTATUS -ne 'Failed')
                    {
                        if ($JSPSTATUS -ne 'PastCompletion')
                            {
                                $JSPSTATUS = 'Unknown'
                                $RUNJSP.content
                            }
                    }
            
                
                
    }
        #write-host "DEBUG: JSP - $JSP - Status = $JSPSTATUS"
        $JSPSTATUSES | Add-Member -Type NoteProperty -Name Status -Value "$JSPSTATUS"
        $JSPSTATUSES | Add-Member -Type NoteProperty -Name Version -Value $JSPS.version
        $JSPSTATUSES | Add-Member -Type NoteProperty -Name JSP -Value "$JSP"
        
        $JSPCOMPLETION += $JSPSTATUSES
        #$JSPSTATUSES
        <#if ($JSPSTATUS)
            {
                allow_ecw_sessionless_url.ps1 --site=$SID --url=$JSP --delete
            }#>

    }
#Write-Output "Adding JSPS to "
foreach ($JSPS in $JSPCOMPLETION)
    {
        $JSP = $JSPS.jsp
        allow_ecw_sessionless_url.ps1 --site=$SID --url=$JSP --delete
    }
#Close-SqlConnection -ConnectionName SQL$SID`_runjsp
#write-host "DEBUG COMPLETION STATUS: $JSPCOMPLETION"
foreach ($J in $JSPCOMPLETION)
    {
        Write-Output "$($J.version), $($J.status)"
    }