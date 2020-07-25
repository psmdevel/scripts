#--Reset Support Password

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module SimplySql
Import-Module $DRIVE\scripts\sources\_functions.psm1

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
        if ($L -eq '--date' -or $L -eq '-d' ){$DATE = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
        if ($ARG -eq '--orderbyusrid' -or $ARG -eq '--orderbyuserid'){$ORDER = 'usrid'} else {$ORDER = 'hostosusr'}
        if ($ARG -eq '--export') {$EXPORT = $TRUE}
        if ($ARG -eq '--showenabled') {$SHOWENABLED = $TRUE}
        if ($ARG -eq '--showfullname') {$SHOWFULLNAME = $TRUE}
        if ($ARG -eq '--rdpusername') {$RDPUSERNAME = $TRUE}
        if ($ARG -eq '--summary') {$SUMMARY = $TRUE}
    }

#--Display available options
if ($HELP -eq 'True')
    {
        [PSCustomObject] @{
        '-h|--help' = 'display available options'
        '-s|--site' = 'display RDP logins for specified site'
        '-d|--date' = 'specify date to search "yyyy-MM"'
        '--orderbyusrid' = 'order display by usrid instead of hostosusr'
        '--export' = 'export to csv'
        '--showenabled' = 'display enabled RDP accounts'
        '--showfullname' = 'display full name of users'
        '--rdpusername' = 'display proposed RDP username'
                        }|Format-List;exit
    }

#Write-Host "Debug: $RDPUSERNAME"

#--Get the site info from database
$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}



#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$Auth_SID = $SHOW.auth_sid

#--Date info
if (!$DATE)
    {
        $DATE = Get-Date -Format yyyy-MM
    }
#--Get the RDP logins for current month
Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Credential $Auth_SID -Database mobiledoc_$SID
$RDPLOGS = @()
$RDPACCOUNTS = Invoke-SqlQuery -Query "select distinct hostosusr from usrlogs where hostosusr like 'mycharts%site$SID%' and hostosusr not like '%\_s0%' and hostosusr not like '%\_s1%' and hostlogintime like '$DATE%' order by hostosusr;"
$RDPLOGINS = Invoke-SqlQuery -Query "select distinct hostosusr,usrid from usrlogs where hostosusr like 'mycharts%site$SID%' and hostosusr not like '%\_s0%' and hostosusr not like '%\_s1%' and hostlogintime like '$DATE%' order by $ORDER;"
foreach ($RDPs in $RDPLOGINS)
    {
        $RDP = $RDPS.hostosusr.split('\')[-1]
        $USR = $RDPS.usrid
        $USRLIST = New-Object System.Object
        $USRLOGINS = Invoke-SqlQuery -Query "select hostosusr,usrname,max(hostlogintime) from usrlogs where usrid = $USR and hostosusr like '%$RDP' and hostlogintime like '$DATE%' order by hostosusr;"
        #$USRLOGINS#|Select-Object usrname -Unique)
        #foreach ($USR in $US)
        $USRLIST | Add-Member -Type NoteProperty -Name hostosusr -Value $USRLOGINS.hostosusr.split('\')[-1]
        $USRLIST | Add-Member -Type NoteProperty -Name usrname -Value $USRLOGINS.usrname
        $USRLIST | Add-Member -Type NoteProperty -Name hostlogintime -Value $USRLOGINS.'max(hostlogintime)'
        #$USERNAMES = @()
        if ($SHOWFULLNAME)
            {
                $USERNAMES = @()
                $FULLNAMES = Invoke-SqlQuery -Query "select ufname,ulname from users where uid = $USR;"
                $USERNAMES += $FULLNAMES.ufname + $FULLNAMES.ulname
                $USERNAMES = $USERNAMES -replace "[^a-zA-Z0-9]",""
                $USERNAMES = $USERNAMES.tolower()
                $USRLIST | Add-Member -Type NoteProperty -Name FullName -Value $USERNAMES
                if ($RDPUSERNAME)
                    {
                        $UFNAME = ($FULLNAMES.ufname -replace "[^a-zA-Z0-9]","").ToLower()
                        $ULNAME = ($FULLNAMES.ulname -replace "[^a-zA-Z0-9]","").ToLower()
                        #write-host "Debug: $UFNAME"
                        #write-host "Debug: $ULNAME"
                        $RDPUSERNAMES = ($ULNAME[0..3] -join "") + ($UFNAME[0..1] -join "")
                        $RDPUSERNAMES = "site$SID`_" + $RDPUSERNAMES
                        $USRLIST | Add-Member -Type NoteProperty -Name NewRDPName -Value $RDPUSERNAMES
                    }
            }

        $RDPLOGS += $USRLIST
        #$RDPLOGS
        #$USRLIST
    }
$RDPLOGS|ft
$RDPCOUNT = (Invoke-SqlQuery -Query "select distinct hostosusr from usrlogs where hostosusr like 'mycharts%site$SID%' and hostosusr not like '%\_s0%' and hostosusr not like '%\_s1%'and hostlogintime like '$DATE%' order by hostosusr;").hostosusr.count
$USRCOUNT = ($RDPLOGINS.usrid|Sort-Object -Unique).count
$ENABLEDACCOUNTS = @()
foreach ($s in Get-ADUser -Filter "name -like 'site$SID`_*' -and enabled -eq 'True' -and name -notlike '*_s0*' -and name -notlike '*_s1*' -and name -notlike '*mapper'" -Properties "lastlogondate","AccountExpirationDate")
    {
        $ENABLEDACCOUNTS += $s|Select-Object samaccountname,lastlogondate,AccountExpirationDate
    }
$ENABLEDCOUNT = $ENABLEDACCOUNTS.count
[PSCustomObject] @{
"Total RDP accounts enabled for site$SID"= $ENABLEDCOUNT
"Total RDP accounts used by site$SID in $DATE"= $RDPCOUNT
"Total RDP users for site$SID in $DATE" = $USRCOUNT
                    }|Format-List

#$ENABLEDACCOUNTS
<#foreach ($ACCOUNT in $ENABLEDACCOUNTS)
    {
        $RDPLOGS |Add-Member -Type NoteProperty -Name 'EnabledAccount' -Value $ACCOUNT
    }#>
$RDPLOGS |Add-Member -Type NoteProperty -Name 'EnabledCount' -Value $ENABLEDCOUNT
$RDPLOGS |Add-Member -Type NoteProperty -Name 'UsedAccounts' -Value $RDPCOUNT
$RDPLOGS |Add-Member -Type NoteProperty -Name 'RDPUserCount' -Value $USRCOUNT
if ($EXPORT)
    {
        Write-Host "Exporting CSV to $env:USERPROFILE\documents\site$SID`_$DATE.csv"
        $RDPLOGS|Export-Csv $env:USERPROFILE\documents\site$SID`_$DATE.csv 
    }
if ($SHOWENABLED)
    {
        if ($ENABLEDCOUNT -gt 0)
            {
                Write-Output "
------------------EnabledAccountNames--------------------"
    <#:                    ......                      :
    :                 .:||||||||:.                   :
    :                /            \                  :
    :               (   o      o   )                 :
    :-------@@@@----------:  :----------@@@@---------:
    :                     ``--'                       :
        "#>
                $ENABLEDACCOUNTS
            }
    }

#$RDPLOGS.EnabledAccount
Close-SqlConnection