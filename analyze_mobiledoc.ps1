#--Analyze Mobiledoc Tables

#--Import the Invoke-Mysql.psm1 module
#$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
#--import sql module
Import-Module SimplySql
$Auth = get-Auth.ps1

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($L -eq '--table') {$TABLE = $R}
        if ($L -eq '--action') {$ACTION = $R}
        #if ($L -eq '--alltables') {$ALLTABLES = $TRUE}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
    }

#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        'Description' = 'Analyzes all mobiledoc_$SID tables'
        '-s|--site' = 'specify only one site (optional)'
        '-h|--help' = 'display available options'
        #'--alltables' = 'analyze all medispan tables'
        } | Format-list;exit
    }

#--actions
$ACTIONS = @('analyze','check','repair')
if ($ACTION)
    {
        if ($ACTIONS -notcontains $ACTION)
            {
                Write-Host "Action specified not valid.";exit
            }
    }

if (!$ACTION)
    {
        $ACTION = 'analyze'
    }

Open-MySqlConnection -Server dbclust11 -Port 5000 -Database control_data -Credential $Auth
if ($m_SID)
    {
        $SITES = Invoke-SqlQuery -Query "select * from sitetab where status like 'a%' and siteid = $m_SID;"
    }
        else
            {
                $SITES = Invoke-SqlQuery -Query "select * from sitetab where status like 'a%' and siteid > 001 order by siteid;"
            }
Close-SqlConnection
#foreach ($s in (find_enabled_patch.ps1 --patch=6275 --status=complete).site)
foreach ($SITE in $SITES)
    {
        #$SITE = invoke-mysql --site=000 --query="select * from sitetab where siteid = $s;"
        $SID = $SITE.siteid
        $SHOW = Show-Site --site=$SID --tool
        $Auth_SID = $SHOW.auth_sid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        #--Check if site uses medispan
        
        #--Open mySQL Connection
        Open-MySqlConnection -Server $DBCLUST -Port 5$SID -Database mobiledoc_$SID -Credential $Auth_SID
        #$MEDISPAN = (Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'enablemedispan';").value
        #if ($MEDISPAN -eq 'yes')
            
        Write-Host "--------------------------------site$SID--------------------------------"
        $TABLES = @()
        if ($TABLE)
            {
                $TEST = Invoke-SqlQuery -Query "select table_name from information_schema.tables where table_name = '$TABLE';"
                if ($TEST)
                    {
                        $TABLES += $TABLE
                    }
            }
                else
                    {
                        foreach ($table_name in (Invoke-SqlQuery -Query "select table_name from information_schema.tables where table_schema = 'mobiledoc_$SID'").table_name)
                            {
                                $TABLES += $table_name
                            }
                    }        
        foreach ($t in $TABLES)
            {
                Invoke-SqlQuery -Query "$ACTION table $t;" -CommandTimeout 0
            }
                    
            
        <#foreach ($table in (invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select table_name from information_schema.tables where table_schema = 'medispan'").table_name)
            {
                invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="analyze table medispan.$table;"
            }#>
        Close-SqlConnection
    }