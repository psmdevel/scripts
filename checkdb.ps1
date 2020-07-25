<#--Checks the CheckDBConnection.jsp for the specified tomcats, defaulting to the interface tomcat. #>

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
{
    #$L = $ARG.split('=')[0]
    #$R = $ARG.split('=')[1]
    $L,$R = $ARG -split '=',2
    if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
    if ($L -eq '--host'){$m_HOST = $R}
    if ($L -eq '--interface' -or '-i'){$INTERFACE = $TRUE}
    if ($L -eq '-a'){$A = $TRUE}
    if ($L -eq '-b'){$B = $TRUE}
    if ($L -eq '--both'){$BOTH = $TRUE}
    if ($L -eq '--all'){$ALL = $TRUE}
    if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    if ($L -eq '--timeout'){$TIMEOUT = $TRUE}
}
If (!$SID) {$HELP = $TRUE}
#--Help
if ($HELP) {
[PSCustomObject] @{
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--interface|-i|-a|-b|--both|all' = "Specify the tomcats to check"
'--timeout' = "Sets invoke-webrequest -timeoutsec to 120"
#'--host' = "Specify a hostname (not required) "
                }|Format-List; exit
            }


If (!$m_HOST) 
        {
            $SHOW = Show-Site --site=$SID --tool
            #$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
            $m_HOST = $SHOW.a3
        }
$TOMCAT = "$m_HOST`:3$SID"
$STATUS = @()
$STATISTICS = New-Object system.object
#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$APP1_TOMCAT = "$APP1`:3$SID"
$APP2_TOMCAT = "$APP2`:3$SID"

#--Get database information and eCW Client Version
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + '_DbUser'
$DBPWD = $SHOW.dbuser_pwd
$SITE_VERSION = (Invoke-MySQL -Site $SID -Query "select value from itemkeys where name = 'clientversion';").value

#--Get status of tomcat service
if ($m_HOST -eq 'lab03')
    {
        $SERVICE = plink -i \scripts\sources\ts01_privkey.ppk root@$m_HOST "service tomcat_$SID status"
        $TOMCATVER = ($SERVICE[0]).split('/')[3]
        #$TEST = ($SERVICE[5]).tostring()
        #$TEST -like '*not*'
        #Write-Host "DEBUG: $TEST"
        if ($SERVICE[-1] -like '*not*')
            {
                $CURRENT_STATUS = 'stopped'
            }
                else
                    {
                        $CURRENT_STATUS = (($SERVICE[-1]).split(' ')[-1]).trimend('.')
                    }
        
    }
        else
            {
                $SERVICE = gwmi -ComputerName $m_HOST win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
                #--Echo status of tomcat service
                $CURRENT_STATUS = $SERVICE.state
                $TOMCATVER = $SERVICE.pathname.split('\')[3]
            }


Write-Output "Site$SID $TOMCATVER is $CURRENT_STATUS on $m_HOST"
$STATISTICS | Add-Member -Type NoteProperty -Name siteid -Value "$SID"
$STATISTICS | Add-Member -Type NoteProperty -Name TomcatHost -Value "$m_HOST"
$STATISTICS | Add-Member -Type NoteProperty -Name Tomcat -Value "$TOMCATVER"
$STATISTICS | Add-Member -Type NoteProperty -Name ServiceState -Value "$CURRENT_STATUS"

if ($CURRENT_STATUS -ne 'running') {Write-Output "Exiting"; exit}

#--Create the request.
$DBURL = "http://$TOMCAT/mobiledoc/jsp/catalog/xml/CheckDBConnection.jsp"
$VERSIONURL = "http://$TOMCAT/mobiledoc/jsp/catalog/xml/CheckServerVersion.jsp"
#$HTTP_Request = [System.Net.WebRequest]::Create($URL)
do 
    {
          Write-Host "waiting for page to respond..."
          sleep 3      
    } 
        until
            ((Invoke-WebRequest $DBURL).content -like '*success*')
if ($TIMEOUT)
    {
        $DB_REQUEST = invoke-webrequest $DBURL -TimeoutSec 120
        $VERSION_REQUEST = invoke-webrequest $VERSIONURL -TimeoutSec 120
    }
        else
            {
                $DB_REQUEST = invoke-webrequest $DBURL 
                $VERSION_REQUEST = invoke-webrequest $VERSIONURL 
            }
$RUNNING_VERSION = $VERSION_REQUEST.content

#--Get the HTTP code as an integer.
$HTTP_Status = [int]$DB_REQUEST.StatusCode
$HTTP_Status2 = [int]$VERSION_REQUEST.StatusCode

If ($HTTP_Status -eq 200)
	{
        $STATISTICS | Add-Member -Type NoteProperty -Name HTTPStatus -Value "OK"
        #Write-Output "HTTP Test OK."
    }
        Else
	        {
                $STATISTICS | Add-Member -Type NoteProperty -Name HTTPStatus -Value "Failed"
                #Write-Output "Page does not respond, check site$SID tomcat service."
            }


#--Check the Database Connection
if ($DB_REQUEST.content -like '*success*') 
	{
        $STATISTICS | Add-Member -Type NoteProperty -Name CheckDB -Value "Success"
        $STATISTICS | Add-Member -Type NoteProperty -Name TomcatVersion -Value "$RUNNING_VERSION"
        $STATISTICS | Add-Member -Type NoteProperty -Name eCWVersion -Value "$SITE_VERSION"
        #Write-Output "Check DB Connection Succeeded"
        #Write-Output "Running version is $RUNNING_VERSION"
    }
        Else
	        {
                $STATISTICS | Add-Member -Type NoteProperty -Name CheckDB -Value "Failed"
                #Write-Output "Check DB Connection Failed"
            }
$STATUS += $STATISTICS
$STATUS#|ft

