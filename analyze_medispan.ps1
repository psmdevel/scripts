#--Analyze medispan tables related to slow Rx lookups

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($L -eq '--alltables') {$ALLTABLES = $TRUE}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
    }

#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        'Description' = 'Analyzes specific medispan tables to resolve a slow Rx lookup issue. Used after applying a medispan patch'
        '-s|--site' = 'specify only one site (optional)'
        '-h|--help' = 'display available options'
        '--alltables' = 'analyze all medispan tables'
        } | Format-list;exit
    }

if ($m_SID)
    {
        $SITES = Show-Site --site=$m_SID --tool
        #$SITES = invoke-mysql --site=000 --query="select * from sitetab where status like 'a%' and siteid = $m_SID;"
    }
        else
            {
                $SITES = Invoke-MySQL -site 000 -query "select * from sitetab where status like 'a%' and siteid > 001 order by siteid;"
            }

#foreach ($s in (find_enabled_patch.ps1 --patch=6275 --status=complete).site)
foreach ($SITE in $SITES)
    {
        #$SITE = invoke-mysql --site=000 --query="select * from sitetab where siteid = $s;"
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        #--Check if site uses medispan
        
        $MEDISPAN = (Invoke-MySQL -site $SID -query "select * from itemkeys where name = 'enablemedispan';").value
        if ($MEDISPAN -eq 'yes')
            {
                Write-Host "--------------------------------site$SID--------------------------------"
                if ($ALLTABLES)
                    {
                        foreach ($table in (Invoke-MySQL -site $SID -query "select table_name from information_schema.tables where table_schema = 'medispan'").table_name)
                            {
                                Invoke-MySQL -site $SID -query "analyze table medispan.$table;"
                            }
                    }
                        else
                            {
                                foreach ($table in 'mmw_drug_kdclink','mmw_di_classlink','mmw_di_int','mmw_med_link')
                                    {
                                        Invoke-MySQL -site $SID -query "analyze table medispan.$table;"
                                    }
                            }
            }
        <#foreach ($table in (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select table_name from information_schema.tables where table_schema = 'medispan'").table_name)
            {
                invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="analyze table medispan.$table;"
            }#>

    }