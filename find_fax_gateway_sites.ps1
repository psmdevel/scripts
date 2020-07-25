#--Find sites on fax01 

#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force


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
    '-d|--date' = 'specify date (yyyy-MM-dd)'
    '--summary' = 'display only sites found configured for PSM-hosted fax gateways'
    '--showpending' = 'display fax counts for found site(s) for faxes in status (logged,pending,sending)'
    } | Format-list;exit
}

$FAXSITES = @()
    
if ($m_SID)
    {
        #$SHOW = Show-Site --site=$m_SID --fax --tool
        $SHOW = Invoke-MySQL -Site 000 -Query "select siteid,keywords,db_cluster,dbuser_pwd from sitetab where siteid = '$m_SID' and status = 'active';"
        $SITEARRAY = @()
        $SITEARRAY += $SHOW
    }
        else
            {
                if ($CLUSTER)
                    {
                        $SITEARRAY = Invoke-MySQL -Site 000 -Query "select siteid,keywords,db_cluster,dbuser_pwd from sitetab where status = 'active' and db_cluster = '$CLUSTER' and siteid > 001 order by siteid;"
                    }
                        else
                            {
                                $SITEARRAY = Invoke-MySQL -Site 000 -Query "select siteid,keywords,db_cluster,dbuser_pwd from sitetab where status = 'active' and fax_gateway = 'fax01' order by siteid;"
                            }
            }

#Write-Host "Debug: $THE_DATE"

#--Get the date
if (!$THE_DATE)
    {
        $THE_DATE = get-date -Format yyyy-MM-dd
        $THE_INBOX_DATE = get-date -Format yyyyMMdd
    }
if ($THE_DATE)
    {
        $THE_INBOX_DATE = ($THE_DATE).replace('-','')

    }
#Write-Host "Debug: $THE_DATE"
#Write-Host "Debug: $THE_INBOX_DATE"

foreach ($SITE in $SITEARRAY)
    {
        #write-host -NoNewline "Site$SID`: "
        $SID = $SITE.siteid
        $SHOW = Show-Site --site=$SID --fax --tool
        $KEYWORDS = $SHOW.keywords
        $DBCLUST = $SHOW.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SHOW.dbuser_pwd
        $SITELIST = New-Object System.Object
        #$FAXSRVITEMKEYS = $SHOW.fax
        $FAXSRVHOSTNAME = $SHOW.fax.FaxServerHostname
        $FAXSRVIP = $SHOW.fax.FaxServerip
        #Write-Output "DEBUG: $SID"
        #Write-Output "DEBUG: $FAXSRVHOSTNAME"
        #Write-Output "DEBUG: $FAXSRVIP"
        #$FAXSRVITEMKEYS = Invoke-MySQL -Site $m_SID -Query "select name,value from itemkeys where name in ('faxserverhostname','faxserverip');"
        if ($FAXSRVHOSTNAME)
            {
                <#if (!$SUMMARY)
                    {
                        Write-Host -NoNewline "Site$SID`: "
                    }#>
                <#if ($FAXSRVHOSTNAME -like '*fax01*' -and $FAXSRVIP -like '*192.168.9.60*' -or $m_SID)
                    {
                        if (!$SUMMARY)
                            {
                                write-host -ForegroundColor Green "[True]"
                            }#>
                        if ($SHOWPENDING)
                            {
                               $FAXOUTBOX = Invoke-MySQL -Site $SID -Query "select faxstatus from faxlogs where faxinittime like '$THE_DATE%'" 
                               $LOGGED = ($FAXOUTBOX|where {$_.faxstatus -eq 'Logged'}|Measure-Object).count
                               $SENDING = ($FAXOUTBOX|where {$_.faxstatus -eq 'Sending'}|Measure-Object).count
                               $PENDING = ($FAXOUTBOX|where {$_.faxstatus -eq 'Pending'}|Measure-Object).count
                               $FAILED = ($FAXOUTBOX|where {$_.faxstatus -eq 'Failed'}|Measure-Object).count
                               $COMPLETED = ($FAXOUTBOX|where {$_.faxstatus -eq 'Completed'}|Measure-Object).count
                               #$LOGGED = (Invoke-MySQL -Site $m_SID -Query "select count(*) from faxlogs where faxstatus = 'logged' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               #$SENDING = (Invoke-MySQL -Site $m_SID -Query "select count(*) from faxlogs where faxstatus = 'sending' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               #$PENDING = (Invoke-MySQL -Site $m_SID -Query "select count(*) from faxlogs where faxstatus = 'pending' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               #$FAILED = (Invoke-MySQL -Site $m_SID -Query "select count(*) from faxlogs where faxstatus = 'failed' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               #$COMPLETED = (Invoke-MySQL -Site $m_SID -Query "select count(*) from faxlogs where faxstatus = 'completed' and faxinittime like '$THE_DATE%'" ).'count(*)'
                               $RECEIVED = (Invoke-MySQL -Site $SID -Query "select count(*) from faxinboxlogs where logdatetime like '$THE_INBOX_DATE%' and status in ('TobeReviewed','Deleted')" ).'count(*)'
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
                                $SITELIST | Add-Member -Type NoteProperty -Name Failed -Value "$FAILED"
                                $SITELIST | Add-Member -Type NoteProperty -Name Completed -Value "$COMPLETED"
                                $SITELIST | Add-Member -Type NoteProperty -Name Received -Value "$RECEIVED"
                            }
                        $FAXSITES += $SITELIST
                            
                    #}
                        <#else
                            {
                                if (!$SUMMARY)
                                    {
                                        write-host -ForegroundColor RED "[False]"
                                    }
                            }#>
            }
    }
$FAXCOUNT = $FAXSITES.count
if ($SUMMARY)
    {
        $FAXSITES|ft
    }
if (!$m_SID)
    {
        Write-Host "

        Total sites on Fax01: $FAXCOUNT"
    }