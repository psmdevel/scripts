#--Prepare the tomcats for a practice to use SSL

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
$HOSTNAME = hostname

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
    }

#--Help
if ($HELP -or !$SID) {
[PSCustomObject] @{
'Description' = 'Prepares the application tomcats by placing the CheckServerUrl.jsp to support the psm_ssl.exe utility'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
                }|Format-List; exit
            }

#--Get the site info from database
$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select s.*,a.a1,a.a2,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join db_clusters d where siteid=$SID and a.id=s.app_cluster_id and d.cluster_name=s.db_cluster;"
if (!$SHOW -or $SHOW.status -like 'i*'){Write-Output "Site$SID does not exist or is inactive";exit}

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Get the tomcat info
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

#--Get the external URL
$H_EXTURL = $SHOW.ext_url
$EXTURL = "https://" + $H_EXTURL

#--Place the CheckServerUrl.jsp file and add it to the ecw_sessionless_url table
if (-not(test-path \\$APP1\site$SID\tomcat7\webapps\mobiledoc\jsp\catalog\xml\CheckServerUrl.jsp))
	{
		Copy-Item $DRIVE\scripts\sources\CheckServerUrl.jsp \\$APP1\site$SID\tomcat7\webapps\mobiledoc\jsp\catalog\xml\
		Copy-Item $DRIVE\scripts\sources\CheckServerUrl.jsp \\$APP2\site$SID\tomcat7\webapps\mobiledoc\jsp\catalog\xml\
		Replace-FileString.ps1 -pattern 'sitexxx-yyyyyyyy.chartwire.com' -replacement $H_EXTURL -path \\$APP1\site$SID\tomcat7\webapps\mobiledoc\jsp\catalog\xml\CheckServerUrl.jsp -overwrite
		Replace-FileString.ps1 -pattern 'sitexxx-yyyyyyyy.chartwire.com' -replacement $H_EXTURL -path \\$APP2\site$SID\tomcat7\webapps\mobiledoc\jsp\catalog\xml\CheckServerUrl.jsp -overwrite
		allow_ecw_sessionless_url.ps1 --site=$SID --url='/mobiledoc/jsp/catalog/xml/CheckServerUrl.jsp'
		setperms.ps1 --site=$SID --both
	}
        else
            {
                Write-Host "CheckServerUrl JSP file found. Exiting."
                exit
            }