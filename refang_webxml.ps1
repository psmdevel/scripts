#--Checks for mobiledoc/WEB-INF/web.xml existence and replaces it if necessary

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($ARG -eq '--force' -or $ARG -eq '-f'){$FORCE = 'True'}
        if ($L -eq '--version' -or $L -eq '-v'){$VERSION = $R}

    }

if ($m_SID)
    {
        $SITEARRAY = @()
        $SITEARRAY += $m_SID
    }
     else
        {
            if ($VERSION)
                {
                    $SITEARRAY = @()
                    $SITES = ecwversions.ps1 --version="$VERSION"
                    $SITEARRAY += $SITES.site
                }
                    else
                            {
    
                                $LIST = Invoke-MySQL -s=000 --query="select siteid from sitetab where siteid > 001 and status = 'active' order by siteid;"
                                $SITEARRAY = $LIST.siteid #|ForEach-Object {$_.ToString("000")}

                            }
        }


#--Debug sitelist
$COUNT = $SITEARRAY.Count
#write-host "DEBUG: List $SITEARRAY"
Write-Host "Sites selected: $COUNT"
#echo "DEBUG: $SITEARRAY"
#echo "DEBUG: $VERSION"

#--Confirmation from user
if (!$m_SID)
    {
        Write-host -NoNewline "Multiple sites selected. Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }


foreach ($SID in $SITEARRAY) 
    {

        #--Get the site information from ControlData
        $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"


        #--Get the tomcat servers
        $APPCID = $SHOW.app_cluster_id[0]
        $APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        $APP1 = $APPID.a1
        $APP2 = $APPID.a2

        #--Get the database information
        $DBCLUSTER = $SHOW.db_cluster
        $DBPWD = $SHOW.dbuser_pwd
        $DBUSER = "site$SID" + "_DbUser"
        
        <#
        Write-Host "DEBUG: db cluster = $DBCLUSTER"
        Write-Host "DEBUG: db password = $DBPWD"
        Write-Host "DEBUG: db user = $DBUSER"
        #>

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

        <#--Test existence of common folder
        $TESTWEBXML1 = Test-Path -Path \\$APP1\site$SID\$APP1TOMCATDIR\webapps\mobiledoc\WEB-INF\web.xml
        $TESTWEBXML2 = Test-Path -Path \\$APP2\site$SID\$APP2TOMCATDIR\webapps\mobiledoc\WEB-INF\web.xml
        if ($TESTWEBXML1 -eq $TRUE -and $TESTWEBXML2 -eq $TRUE -and !$FORCE)
            {Write-Host "Web.xml exists on both app servers for site$SID. Exiting.";if ($m_SID){exit}}

        #--If web.xml is missing on only one tomcat, sync the file from one to the other
        if ($TESTWEBXML1 -eq $TRUE -and $TESTWEBXML2 -eq $FALSE)
            {
                Write-Host "Syncing web.xml from $APP1 to $APP2"
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$SID/$APP1TOMCATDIR/webapps/mobiledoc/WEB-INF/; rsync -avh web.xml $APP2`:/alley/site$SID/$APP2TOMCATDIR/webapps/mobiledoc/WEB-INF/"
                setperms --site=$SID --both
            }
        if ($TESTWEBXML2 -eq $TRUE -and $TESTWEBXML1 -eq $FALSE)
            {
                Write-Host "Syncing web.xml from $APP2 to $APP1"
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$APP2 "cd /alley/site$SID/$APP2TOMCATDIR/webapps/mobiledoc/WEB-INF/; rsync -avh web.xml $APP1`:/alley/site$SID/$APP1TOMCATDIR/webapps/mobiledoc/WEB-INF/"
                setperms --site=$SID --both
            }#>

        #--if web.xml is missing from both tomcats, copy from PatchCentral/patches
        
        #if ($TESTWEBXML1 -eq $FALSE -and $TESTWEBXML2 -eq $FALSE -or $FORCE)
            #{
                #--Get client version itemkey
                $CVItemkey = Invoke-MySQL --site=$SID --host=$DBCLUSTER --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'ClientVersion';"
                $CV = $CVItemkey.value

                #--Get the patch number that corresponds with ClientVersion
                $CVPatch = Invoke-MySQL --site=$SID --host=$DBCLUSTER --user=$DBUSER --pass=$DBPWD --query="select ecwpatchid from patcheslist where patchdescription = '$CV' and status = 'complete';"
                $PATCH = $CVPatch.ecwpatchid

                #--Confirm that the PatchCentral web.xml for the patch is available
                $TESTPATCH = Test-Path -Path "\\mgt01a\m$\scripts\PatchCentral\patches\patch_$PATCH\server\webapps\mobiledoc\WEB-INF\web.xml"

                if ($TESTPATCH -eq $FALSE)
                    {Write-Host "web.xml file not found for patch_$PATCH"|Tee-Object $DRIVE\scripts\logs\refang_webxml.log -Append;if ($m_SID){exit}}

                if ($TESTPATCH -eq $TRUE)
                    {
                        if ($FORCE)
                            {setperms --site=$SID --both --unlock}                        
                        Write-Host -NoNewline "Copying web.xml file for patch_$PATCH to both app servers..."
                        cpi \\mgt01a\m$\scripts\PatchCentral\patches\patch_$PATCH\server\webapps\mobiledoc\WEB-INF\web.xml \\$APP1\site$SID\$APP1TOMCATDIR\webapps\mobiledoc\WEB-INF\
                        cpi \\mgt01a\m$\scripts\PatchCentral\patches\patch_$PATCH\server\webapps\mobiledoc\WEB-INF\web.xml \\$APP2\site$SID\$APP2TOMCATDIR\webapps\mobiledoc\WEB-INF\
                        Write-Host "Done"
                        setperms --site=$SID --both
                    }
            #}
    }