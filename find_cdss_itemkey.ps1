#--Find sites with cdss itemkey

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

<#foreach ($ARG in $ARGS)
    {
        if ($ARG -like '*:*' -and $ARG -notlike '*:\*'){Write-Output 'Please use "=" to specify arguments'; exit}
        $L,$R = $ARG -split '=',2
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        if ($L -eq '--status' -or $L -eq '-s' ){$STATUS = $R}
        if ($L -eq '--version' -or $L -eq '-v' ){$VERSION = $TRUE}
        if ($L -eq '--cluster' -or $L -eq '-c' ){$CLUSTER = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = '-h'}
    }#>

#if (!$PATCH -and !$STATUS -and !$HELP) {$HELP = '-h'}

<#if ($HELP)
    {
     plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch -h;exit
    }   

if (!$STATUS)
    {
        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch --patch=$PATCH
    }
        else
            {plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 /scripts/find_enabled_patch --patch=$PATCH --status=$STATUS}

#>
#--Get the list of active sites
if ($CLUSTER)
    {
        $SITEARRAY = invoke-mysql --site=000 --query="select * from sitetab where siteid > 001 and status = 'active' and db_cluster = '$CLUSTER' order by siteid;"
    }
        else
            {
                $SITEARRAY = invoke-mysql --site=000 --query="select * from sitetab where siteid > 001 and status = 'active' order by siteid;"
            }
$SITELIST = @()
foreach ($SITE in $SITEARRAY)
    {
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SITE.dbuser_pwd
        $CDSSLIST = New-Object System.Object

        if (!$STATUS)
            {
                $SQUERY = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'cdssImmForecastingUrl' and value = 'cdss.eclinicalworks.com';"
                if ($VERSION)
                    {
                        $SITE_VERSION = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'clientversion';"
                    }
            }
                else
                    {
                        $SQUERY = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select ecwpatchid,patchdescription,status from patcheslist where ecwpatchid='$PATCH' and status='$STATUS';"
                        if ($VERSION)
                            {
                                $SITE_VERSION = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'clientversion';"
                            }
                    }
        if ($SQUERY)
            {
                $APUID = (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'autoupgradekey';").value
                $ECWPATCHID = $SQUERY.ecwpatchid
                $PATCHDESC = $SQUERY.patchdescription
                $CDSSSTATUS = $SQUERY.value
                $CDSSLIST | Add-Member -Type NoteProperty -Name Site -Value "$SID"
                $CDSSLIST | Add-Member -Type NoteProperty -Name APUID -Value "$APUID"
                #$CDSSLIST | Add-Member -Type NoteProperty -Name Description -Value "$PATCHDESC"
                $CDSSLIST | Add-Member -Type NoteProperty -Name Status -Value "$CDSSSTATUS"
                if ($VERSION)
                    {
                        $SITE_VERSION = $SITE_VERSION.value
                        $CDSSLIST | Add-Member -Type NoteProperty -Name ClientVersion -Value "$SITE_VERSION"
                    }
                #--Update the cdssImmForecastingurl itemkey to 'cdss.eclinicaweb.com'
                invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="update itemkeys set value = 'cdss.eclinicalweb.com' where value = 'cdss.eclinicalworks.com' and name = 'cdssImmForecastingUrl' limit 1;"
                $SQUERY2 = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'cdssImmForecastingUrl' and value = 'cdss.eclinicalweb.com';"
                $CDSSSTATUS2 = $SQUERY2.value
                $CDSSLIST | Add-Member -Type NoteProperty -Name Status2 -Value "$CDSSSTATUS2"
                $SITELIST += $CDSSLIST
                $CDSSLIST
            }
    }

if (!$STATUS){$STATUS = 'any'}
#$SITELIST
$TOTAL = $SITELIST.count
Write-host "Total sites with cdss.eclinicalworks.com value for cdssImmForecastingUrl itemkey: $TOTAL"

            

