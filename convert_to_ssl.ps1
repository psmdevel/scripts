#--Convert site to use SSL (HTTPS)

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module M:\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
        if ($ARG -eq '--revert'){$REVERT = $TRUE}       
        if ($ARG -eq '--restart'){$m_RESTART = $TRUE}
        if ($ARG -eq '--tomcat-only'){$TOMCATONLY= $TRUE}
    }

#--Get the site info from database
$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2

#--Get the speciality_form form_url addresses
Write-Host "Checking for speciality_forms..."
$FORMURLS = @()
$FORMS = (Invoke-MySQL -site $SID -query "select form_url from speciality_forms where form_url like '%:3$SID%';").form_url
#$FORMS
#$FORMS = $FORMS.split('/')[2]|sort -Unique
#$FORMS
foreach ($FORM in $FORMS)
    {
        #$FORM = $FORM.split('/')[2]
        #$FORM = $FORM|sort -Unique
        $FORMURLS += $FORM.split('/')[2]
        
    }
$FORMCOUNT = $FORMS.count
$FORMURLS = $FORMURLS|sort -Unique
#$FORMURLS
#$FORMCOUNT

#--Get the document filename addresses
Write-Host "Checking for smart form documents..."
$DOCURLS = @()
$DOCUMENTS = (Invoke-MySQL -site $SID -query  "select filename from document where filename like '%:3$SID%';").filename
#$FORMS
#$FORMS = $FORMS.split('/')[2]|sort -Unique
#$FORMS
foreach ($DOC in $DOCUMENTS)
    {
        #$FORM = $FORM.split('/')[2]
        #$FORM = $FORM|sort -Unique
        $DOCURLS += $DOC.split('/')[2]
        
    }
$DOCCOUNT = $DOCUMENTS.count
$DOCURLS = $DOCURLS|sort -Unique
#$DOCURLS
#$DOCCOUNT

#--get the ftp port number from the ftpconfig table and ensure that the ftp_params table matches
$FTPPORT = (Invoke-MySQL -site $SID -query "select * from ftpconfig;").port
$FTPPARAMSPORT = (Invoke-MySQL -site $SID -query  "select * from ftp_params;").ftpportno
if ($FTPPARAMSPORT -ne $FTPPORT)
    {
        $UPDATEFTPPORT = $TRUE
    }
        else
            {
                $UPDATEFTPPORT = $FALSE
            }

#--Get related itemkeys
$USEHTTP = Invoke-MySQL -site $SID -query "select * from itemkeys where name = 'UseHttpInstdOfFtpVB';"
$EMRSRV = Invoke-MySQL -site $SID -query "select itemid,value from itemkeys where name in ('EMR_SrvHostName','EMR_SrvProtocol','EPCS_AppSrv_Protocol','EPCS_Srv_HostName');"
#--Get the external URL
$H_EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01b "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"
#$H_EXTURL = $EXTURL
$EXTURL = "https://" + $H_EXTURL

[PSCustomObject] @{
  Site     = $SID
  SSL_URL = $EXTURL 
  Speciality_form_count = $FORMCOUNT
  Document_file_count= $DOCCOUNT
  Update_ftp_params_port   = $UPDATEFTPPORT
  EMR_SrvHostName = $EMRSRV[0].value
  EMR_SrvProtocol = $EMRSRV[1].value
  EPCS_Srv_HostName = $EMRSRV[3].value
  EPCS_AppSrv_Protocol = $EMRSRV[2].value


} | Format-list

#--Confirmation from user
Write-host -NoNewline "Performs the conversion to using SSL instead of plain HTTP.

Enter 'PROCEED' to continue: "
$RESPONSE = read-host
if ($RESPONSE -cne 'PROCEED') {exit}

#--Update speciality_forms form_url entries
foreach ($FORMURL in $FORMURLS)
    {
        Invoke-MySQL -site $SID -update -query "update speciality_forms set form_url = replace(form_url, 'http://$FORMURL', '$EXTURL') where form_url like ('http://$FORMURL%');"
    }


#--Update document table filename entries
foreach ($DOCURL in $DOCURLS)
    {
        Invoke-MySQL -site $SID -update -query "update document set filename = replace(filename, 'http://$DOCURL', '$EXTURL') where filename like ('http://$DOCURL%');"
    }

#--Set the ftp_parms FtpPortNo
if ($UPDATEFTPPORT -eq $TRUE)
    {
        Invoke-MySQL -site $SID -update -query "update ftp_params set ftpportno = $FTPPORT;"
    }

#--Update itemkeys
Invoke-MySQL -site $SID -update -query "update itemkeys set itemid = 1, value = 'yes' where name = 'UseHttpInstdOfFtpVB' limit 1;"
Invoke-MySQL -site $SID -update -query "update itemkeys set value = '$H_EXTURL' where name = 'EMR_SrvHostName' limit 1;"
Invoke-MySQL -site $SID -update -query "update itemkeys set value = 'https:' where name = 'EMR_SrvProtocol' limit 1;"
Invoke-MySQL -site $SID -update -query "update itemkeys set value = '$H_EXTURL' where name = 'EPCS_Srv_HostName' limit 1;"
Invoke-MySQL -site $SID -update -query "update itemkeys set value = 'https:' where name = 'EPCS_AppSrv_Protocol' limit 1;"

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
                Write-Host "CheckServerUrl JSP file found. Skipping."
                #exit
            }

#--Check your work
$CHECKDOC = (Invoke-MySQL -site $SID -query "select filename from document where filename like '%$H_EXTURL%';").count
$CHECKFORMS = (Invoke-MySQL -site $SID -query "select form_url from speciality_forms where form_url like '%:$H_EXTURL%';").count
if ($CHECKDOC -eq $DOCCOUNT)
    {
        Write-Host ""
    }

#--Restart tomcats if requested
if ($m_RESTART)
    {
        safe_tomcat.ps1 --site=$SID --restart --fast --both
    }