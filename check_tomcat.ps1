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
    if ($L -eq '--interface' -or $L -eq '-i'){$INTERFACE = $TRUE}
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
'--interface|-i|-a|-b|--both|--all' = "Specify the tomcats to check"
'--timeout' = "Sets invoke-webrequest -timeoutsec to 120"
#'--host' = "Specify a hostname (not required) "
                }|Format-List; exit
            }



$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -like 'i*')
    {
        Write-Host "Specified site is inactive. Exiting";exit
    }
$m_HOST = $SHOW.a3


$STATUS = @()

#--Select tomcats to check
$TOMCAT_ARRAY = @()
if ($BOTH)
    {
        $A = $TRUE
        $B = $TRUE
    }
if ($ALL)
    {
        $A = $TRUE
        $B = $TRUE
        $INTERFACE = $TRUE
    }
#--Get the tomcat info
#$APPCID = $SHOW.app_cluster_id[0]
#$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$APP1_TOMCAT = "$APP1`:3$SID"
$APP2_TOMCAT = "$APP2`:3$SID"
if ($INTERFACE)
    {
        if ($SHOW.a3 -like 'lab*')
            {
                $APP3 = $SHOW.interface_server
                #$TOMCAT = "$APP3`:3$SID"
                $APP3_TOMCAT = "$APP3`:3$SID"
            }
    }
if ($A) {$TOMCAT_ARRAY += $APP1}
if ($B) {$TOMCAT_ARRAY += $APP2}
if ($INTERFACE) {$TOMCAT_ARRAY += $APP3}

#--Get database information and eCW Client Version
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + '_DbUser'
$DBPWD = $SHOW.dbuser_pwd
$SITE_VERSION = $show.clientversion
# = (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'clientversion';").value



#Write-Host "Debug: " $TOMCAT_ARRAY
#Write-Host "Debug: " $INTERFACE
#--Get status of tomcat service for selectec tomcats
foreach ($APP in $TOMCAT_ARRAY)
    {
        $STATISTICS = New-Object system.object
        $TOMCAT = "$APP`:3$SID"
        if ($APP -like 'app*')
            {
                $SERVICE = Connect-Ssh -ComputerName $APP -ScriptBlock "service tomcat_$SID status"
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
                        #write-host "debug: $APP"
                        $SERVICE = gwmi -ComputerName $APP win32_service|?{$_.Name -eq "$SID"}|select name, displayname, startmode, state, pathname, processid
                        #--Echo status of tomcat service
                        $CURRENT_STATUS = $SERVICE.state
                        $TOMCATVER = $SERVICE.pathname.split('\')[3]
                    }


        #Write-Output "Site$SID $TOMCATVER is $CURRENT_STATUS on $m_HOST"
        $STATISTICS | Add-Member -Type NoteProperty -Name siteid -Value "$SID"
        $STATISTICS | Add-Member -Type NoteProperty -Name TomcatHost -Value "$APP"
        $STATISTICS | Add-Member -Type NoteProperty -Name Tomcat -Value "$TOMCATVER"
        $STATISTICS | Add-Member -Type NoteProperty -Name ServiceState -Value "$CURRENT_STATUS"

        if ($CURRENT_STATUS -ne 'running') {break }#Write-Output "Exiting"; exit}

        #--Create the request.
        $DBURL = "http://$TOMCAT/mobiledoc/jsp/catalog/xml/CheckDBConnection.jsp"
        $VERSIONURL = "http://$TOMCAT/mobiledoc/jsp/catalog/xml/CheckServerVersion.jsp"
        #$HTTP_Request = [System.Net.WebRequest]::Create($URL)
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
}
$STATUS#|ft * -AutoSize
