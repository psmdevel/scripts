#--Find sites on fax01 

#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        #if ($L -eq '--date' -or $L -eq '-d'){$THE_DATE = $R}
        if ($L -eq '--cluster' -or $L -eq '-c'){$CLUSTER = $R}
        if ($L -eq '--date' -or $L -eq '-d'){$THE_DATE = $R}
        #if ($ARG -eq '--remaining'){$REMAINING = $TRUE}
        if ($ARG -eq '--summary'){$SUMMARY = $TRUE}
        if ($ARG -eq '--showpending'){$SHOWPENDING = $TRUE}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Display available options
if ($HELP)
{
    [PSCustomObject] @{
    'Description' = 'Find sites on PSM-hosted fax gateways (currently only fax01)'
    '-h|--help' = 'display available options'
    '-s|--site' = 'specify only one site'
    '--summary' = 'display only sites found configured for PSM-hosted fax gateways'
    '--showpending' = 'display fax counts for found site(s) for faxes in status (logged,pending,sending)'
    } | Format-list;exit
}

$FAXSITES = @()
    
if ($m_SID)
    {
        $SHOW = invoke-mysql --site=000 --query="select siteid,keywords,db_cluster,dbuser_pwd from sitetab where siteid = '$m_SID' and status = 'active';"
        $SITEARRAY = @()
        $SITEARRAY += $SHOW
    }
        else
            {
                if ($CLUSTER)
                    {
                        $SITEARRAY = invoke-mysql --site=000 --query="select siteid,keywords,db_cluster,dbuser_pwd from sitetab where status = 'active' and db_cluster = '$CLUSTER' and siteid > 001 order by siteid;"
                    }
                        else
                            {
                                $SITEARRAY = invoke-mysql --site=000 --query="select siteid,keywords,db_cluster,dbuser_pwd from sitetab where status = 'active' and siteid > 001 order by siteid;"
                            }
            }

Write-Host "Debug: $THE_DATE"

#--Get the date
if (!$THE_DATE)
    {
        $THE_DATE = get-date -Format yyyy-MM-dd
    }


foreach ($SITE in $SITEARRAY)
    {
        #write-host -NoNewline "Site$SID`: "
        $SID = $SITE.siteid
        $KEYWORDS = $SITE.keywords
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        $SITELIST = New-Object System.Object
        $FAXSRVITEMKEYS = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select name,value from itemkeys where name in ('faxserverhostname','faxserverip');"
        if ($FAXSRVITEMKEYS)
            {
                if (!$SUMMARY)
                    {
                        Write-Host -NoNewline "Site$SID`: "
                    }
                if ($FAXSRVITEMKEYS.value[0] -eq 'fax01' -and $FAXSRVITEMKEYS.value[1] -eq '192.168.9.60')
                    {
                        if (!$SUMMARY)
                            {
                                write-host -ForegroundColor Green "[True]"
                            }
                        if ($SHOWPENDING)
                            {
                               $LOGGED = (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from faxlogs where faxstatus = 'logged' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               $SENDING = (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from faxlogs where faxstatus = 'sending' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               $PENDING = (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select count(*) from faxlogs where faxstatus = 'pending' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               #$SITELIST | Add-Member -Type NoteProperty -Name Logged -Value "$LOGGED"
                               #$SITELIST | Add-Member -Type NoteProperty -Name Sending -Value "$SENDING"
                               #$SITELIST | Add-Member -Type NoteProperty -Name Pending -Value "$PENDING"
                            }
                        $SITELIST | Add-Member -Type NoteProperty -Name Site -Value "$SID"
                        if ($SHOWPENDING)
                            {
                                $SITELIST | Add-Member -Type NoteProperty -Name Logged -Value "$LOGGED"
                                $SITELIST | Add-Member -Type NoteProperty -Name Sending -Value "$SENDING"
                                $SITELIST | Add-Member -Type NoteProperty -Name Pending -Value "$PENDING"
                            }
                        $FAXSITES += $SITELIST
                            
                    }
                        else
                            {
                                if (!$SUMMARY)
                                    {
                                        write-host -ForegroundColor RED "[False]"
                                    }
                            }
            }
    }
$FAXCOUNT = $FAXSITES.count
if ($SUMMARY)
    {
        $FAXSITES
    }
if (!$m_SID)
    {
        Write-Host "

        Total sites on Fax01: $FAXCOUNT"
    }