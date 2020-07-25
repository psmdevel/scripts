#--ecwversions, but for powershell!

#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module M:\scripts\sources\_functions.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--cluster' -or $L -eq '-c'){$CLUSTER = $R}
        if ($L -eq '--version' -or $L -eq '-v'){$VERSION = $R}
        if ($L -eq '--serverversion'){$SERVERVERSION = $TRUE}
        if ($L -eq '--reseller' -or $L -eq '-r'){$RESELLER = $R}
        if ($L -eq '--support'){$SUPPORT = $R}
        if ($L -eq '--keywords'){$KEYWORDS = $R}
        if ($ARG -eq '--notmatching'){$NOTMATCH = $TRUE}
        if ($ARG -eq '--tomcat' -or $L -eq '-t'){$TOMCAT = $TRUE}
        if ($ARG -eq '--url' -or $L -eq '-u'){$GETURL = $TRUE}
        if ($ARG -eq '--drug'){$GETDRUG = $TRUE}
        if ($ARG -eq '--loggedin'){$LOGGEDIN = $TRUE}
        if ($ARG -eq '--ebo'){$GETEBO = $TRUE}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Display eCW Client versions"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number. May be left unspecified"
'--version|-v' = "Specify a version to search for"
'--serverversion' = "Display ecwserverversion itemkey value"
'--cluster' = "Show sites on a given cluster. ex.: dbclust09, app10, lab03, cognos02, ts13"
'--reseller' = "Show sites supported by a given reseller"
'--support' = "Show sites supported by a given support provider"
'--notmatching' = "Used with '--version'. Omit sites matching the specified version"
'--tomcat' = "Display application tomcat versions"
'--drug' = "Display formulary vendor, Medispan or Multum"
'--url' = "Display the web client URL"
'--loggedin' = "Display if there are active user logins this month"
'--ebo' = "Show ebo version itemkey value"
                }|Format-List; exit
            }

if ($m_SID)
    {
        $SHOW = Show-Site --site=$m_SID
        #$SHOW = invoke-mysql -site 000 -query "select * from sitetab where siteid = '$m_SID' and status = 'active';"
        $SITEARRAY = @()
        $SITEARRAY += $SHOW
    }
        else
            {
                if ($CLUSTER)
                    {
                        if ($CLUSTER -like 'virtdb*' -or $CLUSTER -like 'dbclust*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and db_cluster = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'app*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and app_cluster_id = (select id from app_clusters where a1 = '$CLUSTER' or a2 = '$CLUSTER') and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'ts*' -or $CLUSTER -like 'rdp*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and ts_cluster_id = (select id from ts_clusters where rdp_address like '$CLUSTER%' or t1 = '$CLUSTER' or t2 = '$CLUSTER') and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'lab*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and interface_server = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                        if ($CLUSTER -like 'cognos*' -or $CLUSTER -like 'vmhost*')
                            {
                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and ebo_server = '$CLUSTER' and siteid not in (000,001,119,780,999) order by siteid;"
                            }
                    }
                        else
                            {
                                if ($RESELLER)
                                    {
                                        $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and reseller_id = '$RESELLER' and siteid not in (000,001,119,780,999) order by siteid;"
                                    }
                                        else
                                            {
                                                if ($SUPPORT)
                                                    {
                                                        $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and support_id = '$SUPPORT' and siteid not in (000,001,119,780,999) order by siteid;"
                                                    }
                                                        else
                                                            {
                                                                if ($KEYWORDS)
                                                                    {
                                                                        $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and siteid not in (000,001,119,780,999) and keywords like '%$KEYWORDS%' order by siteid;"
                                                                    }
                                                                        else
                                                                            {
                                                                                $SITEARRAY = Invoke-MySQL -site 000 -query "select * from sitetab where status = 'active' and siteid not in (000,001,119,780,999) order by siteid;"
                                                                            }
                                                            }
                                            }
                            }
            }

$VERSIONTABLE = @()



foreach ($SITE in $SITEARRAY)
    {
        $SID = $SITE.siteid
        $SHOW = Show-Site --site=$SID --tool -p
        $KEYWORDS = $SITE.keywords
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        $APU = $SITE.apu_id
        #$APPCID = $SITE.app_cluster_id[0]
        #$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        $APP1 = $SHOW.a1
        $APP2 = $SHOW.a2
        $VERSIONLIST = New-Object System.Object
        $SITE_VERSION = $SHOW.clientversion
        #$SITE_VERSION = $SITE_VERSION.value
        $VERSIONLIST | Add-Member -Type NoteProperty -Name Site -Value "$SID"
        $VERSIONLIST | Add-Member -Type NoteProperty -Name Version -Value "$SITE_VERSION"
        $VERSIONLIST | Add-Member -Type NoteProperty -Name APU_ID -Value "$APU"
        $VERSIONLIST | Add-Member -Type NoteProperty -Name Description -Value "$KEYWORDS"
        if ($SERVERVERSION)
            {
                $ECWSERVERVERSION = $SHOW.serverversion
                $VERSIONLIST | Add-Member -Type NoteProperty -Name eCWServerVersion -Value "$ECWSERVERVERSION"
            }
        if ($GETURL)
            {
                #$EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01 "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"
                $EXTURL = $SHOW.ext_url
                #$EXTURL = "https://$($SHOW.ext_url)/mobiledoc/jsp/webemr/login/newLogin.jsp"
                $VERSIONLIST | Add-Member -Type NoteProperty -Name WebURL -Value "$EXTURL"
            }
        if ($GETDRUG)
            {
                $MEDISPAN = $SHOW.medispan
                #$MEDISPAN = (Invoke-MySQL -site $SID -query "select * from itemkeys where name = 'enablemedispan';").value
                if ($MEDISPAN -eq 'yes')
                    {
                        $FORMULARY = 'Medispan'
                        #--Find last Medispan update applied
                        $LASTFORM = ($SHOW.patches|where {$_.patchdescription -like '*medispan*' -and $_.status -eq 'complete'}|select -Last 1).ecwpatchid
                        #$LASTFORM = (Invoke-MySQL -site $SID -query "select * from patcheslist where patchdescription like '%medispan%' and status = 'complete' order by ecwpatchid desc;").ecwpatchid[0]
                        $VERSIONLIST | Add-Member -Type NoteProperty -Name Formulary -Value "$FORMULARY"
                        $VERSIONLIST | Add-Member -Type NoteProperty -Name FormularyPatch -Value "$LASTFORM"
                    }
                        else
                            {
                                $FORMULARY = 'Multum'
                                #--Find last Medispan update applied
                                $LASTFORM = ($SHOW.patches|where {$_.patchdescription -like '*multum*' -and $_.status -eq 'complete'}|select -Last 1).ecwpatchid
                                #$LASTFORM = (Invoke-MySQL -site $SID -query "select * from patcheslist where patchdescription like '%multum%' and status = 'complete' order by ecwpatchid desc;").ecwpatchid[0]
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Formulary -Value "$FORMULARY"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name FormularyPatch -Value "$LASTFORM"
                            }
            }
        if ($LOGGEDIN)
            {
                $DATE = (get-date -Format yyyy-MM)
                $USRLOGS = Invoke-MySQL -site $SID -query "select * from usrlogs where serverlogintime like '$DATE%' and usrname not like '%support';"
                if ($USRLOGS.count -gt 0)
                    {
                        $SITEACTIVE = $TRUE
                        $VERSIONLIST | Add-Member -Type NoteProperty -Name Active -Value "$SITEACTIVE"
                    }
                        else
                            {
                                $SITEACTIVE = $FALSE
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Active -Value "$SITEACTIVE"
                            }
            }
        if ($GETEBO)
            {
                
                $EBOURL = $SHOW.ebo_url
                #$EBOURL = (Invoke-MySQL -site $SID -query "select value from itemkeys where name = 'eBOURL';").value
                if ($EBOURL -like "*$SID*")
                    {
                        $EBOVER = $SHOW.ebo_version
                        #$EBOVER =  (Invoke-MySQL -site $SID -query "select value from itemkeys where name = 'eBOPackageVersion';").value
                        if ($EBOVER)
                            {
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name eBO -Value "$EBOVER"
                            }
                    }
            }
        #Write-Output "~: $SID`: $SITE_VERSION - $APU - $KEYWORDS"
        if ($VERSION -and $NOTMATCH)
            {
                if ($SITE_VERSION -notlike "*$VERSION*")
                    {
                        if ($TOMCAT)
                            {
                                #--Get the tomcat versions                
                                $APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $APP2_TC_VERSION = Connect-Ssh -ComputerName $APP2 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_A -Value "$APP1_TC_VERSION"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_B -Value "$APP2_TC_VERSION"
                            }
                        $VERSIONTABLE += $VERSIONLIST
                        $VERSIONLIST
                    }
            }

        if ($VERSION -and !$NOTMATCH)
            {
                if ($SITE_VERSION -like "*$VERSION*")
                    {
                        if ($TOMCAT)
                            {            
                                $APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $APP2_TC_VERSION = Connect-Ssh -ComputerName $APP2 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_A -Value "$APP1_TC_VERSION"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_B -Value "$APP2_TC_VERSION"
                            }
                        $VERSIONTABLE += $VERSIONLIST
                        $VERSIONLIST  
                    }
            }
        if (!$VERSION -and !$NOTMATCH)
                    {
                        if ($TOMCAT)
                            {              
                                $APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $APP2_TC_VERSION = Connect-Ssh -ComputerName $APP2 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_A -Value "$APP1_TC_VERSION"
                                $VERSIONLIST | Add-Member -Type NoteProperty -Name Tomcat_B -Value "$APP2_TC_VERSION"
                            }
                        $VERSIONTABLE += $VERSIONLIST
                        $VERSIONLIST
                    }
        
                
            
        
                        #$VERSIONLIST|Select-Object site,Version,apu_id,description
        
        
    }
#$VERSIONTABLE|ft

if ($VERSION)
    {
        $VERSION_COUNT = $VERSIONTABLE.count
        Write-Output "
Total sites matching '$VERSION': $VERSION_COUNT"
    }
