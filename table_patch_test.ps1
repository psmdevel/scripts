#--Checks for the existence of a specified table for all sites with a specified patch enabled

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        if ($L -eq '--table' -or $L -eq '-t' ){$TABLENAME = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = 'True'}
        if ($L -eq '--status'){$m_STATUS = $R}
        #if ($ARG -eq '--count'){$COUNT = $TRUE}
    }

#--Display available options
if ($HELP -eq 'True')
{
    [PSCustomObject] @{
    '-s|--site' = 'specify only one site'
    '-h|--help' = 'display available options'
    '-p|--patch' = 'set patch number'
    '-t|--table' = 'specify name of table to search for'
    } | Format-list;exit
}

#--Check required variables
if (!$PATCH) {Write-Host "Please specify a patch number using --patch";exit}
if (!$TABLENAME) {Write-Host "Please specify a table name using --table";exit}

#--Populate list of sites to test against using find_enabled_patch
$SHOWSID = @()
if ($m_SID)
    {
        $SHOWSID += $m_SID
    }
    else
        {
            foreach ($FE1 in (Invoke-MySQL -site 000 -query "select siteid from mass_deploy where patchid = 7492 and status = 'completed' order by siteid").siteid)
                {
                    $SHOWSID += $FE1
                }
            
            <#$SID
            (query_mass_deploy.ps1 --patch=$PATCH --nosummary).count
            foreach ($s in (query_mass_deploy.ps1 --patch=$PATCH --nosummary).siteid) 
                {
                    Write-Host "CAN YOU FEEL $s NOW MR. CRABS?"
                    $s
                    $SHOWSID += $s
                }#>
        }

$SITEARRAY = $SHOWSID

<#--Debugging
Write-host "DEBUG: Site = $SID"
Write-host "DEBUG: Site = $m_SID"
Write-Host "DEBUG: Patch = $PATCH"
Write-Host "DEBUG: Table = $TABLENAME"
Write-Host "DEBUG: Showlist = $SHOWSID"
Write-Host "DEBUG: Sitelist = $SITEARRAY"
#>
$SITE_STATUS = @()

foreach ($SID in $SITEARRAY)
    {
        #--Get the site information from ControlData
        $SHOW = Show-Site --site=$SID
        #$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
        $TABLE_STATUS = New-Object system.object
        $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name Site -Value $SID
        #--Get the DB info
        $DBCLUST = $SHOW.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SHOW.dbuser_pwd
        #--Get the database cluster details
        #$DBDETAILS = invoke-mysql -s=000 --query="select * from db_clusters where cluster_name = '$DBCLUST';"
        #write-host "DEBUG: $DBDETAILS"
        #$N1 = $DBDETAILS.n1
        #$N2 = $DBDETAILS.n2
        #$MYSQLROOT = $DBDETAILS.mysql_root
        #write-host "DEBUG: /$MYSQLROOT/site$SID/mysql/data/mobiledoc_$SID/"
        #$MYSQLROOT = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "for s in /ha*;do find `$s -maxdepth 2 -name site$SID;done"
        #$TABLE1 = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "/bin/ls -alt /$MYSQLROOT/site$SID/mysql/data/mobiledoc_$SID/|grep $TABLENAME.MYD"
        $TABLE1 = Invoke-MySQL -site $SID -query "select count(*) from $TABLENAME;"
        #$TABLE2 = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$DBCLUST "/bin/ls -alt /$MYSQLROOT/site$SID/mysql/data/mobiledoc_$SID/|grep $TABLENAME.ibd"

        <#--Debugging
        Write-host "DEBUG: dbcluster = $DBCLUST"
        Write-host "DEBUG: HAMYSQL/site = $MYSQLROOT" 
        Write-host "DEBUG: dbcluster = $DBCLUST"
        Write-host "DEBUG: Table1 = $TABLE1"
        Write-host "DEBUG: Table2 = $TABLE2"
        #>
        if ($TABLE1) 
            {
                $TABLETEST = "Success"
                $T1COUNT = $TABLE1.'count(*)'
                $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name TableName -Value $TABLENAME
                $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name Status -Value $TABLETEST
                $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name RowCount -Value $T1COUNT
            }
                else
                    {
                        $TABLETEST = 'Fail'
                        $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name TableName -Value $TABLENAME
                        $TABLE_STATUS| Add-Member -MemberType NoteProperty -Name Status -Value $TABLETEST
                    }
        $SITE_STATUS +=$TABLE_STATUS
        $TABLE_STATUS
        #Write-Host "~:Site$SID - $TABLETEST - $T1COUNT "<#- $TABLE1 - $TABLE2"#>
    }