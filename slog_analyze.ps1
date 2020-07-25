#--Slow query analyzer

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
        if ($L -eq '--date' -or $L -eq '-d'){$DATE = $R}
        if ($L -eq '--slave') {$SLAVE = 'slave'}
        if ($ARG -eq '-f' -or $ARG -eq '--format') {$FORMATTABLE = $TRUE}
        if ($ARG -eq '--enable') {$ENABLE = $TRUE}
    }

$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"
if (!$SHOW -or $SHOW.status -eq 'inactive')
    {
        Write-Output "Site$SID does not exist or is inactive";exit
    }
if ($SLAVE)
    {
        if (!$SHOW.slave_server)
            {
                Write-Output "Slave specified, but site$SID does not have a slave database";exit
            }
    }
#--Get info from the site DB
if ($SLAVE)
    {
        $DBCLUST = $SHOW.slave_server
    }
        else
            {
                $DBCLUST = $SHOW.db_cluster
            }
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$HA = $SHOW.mysql_root

#--Set the date
if ($DATE)
    {
        $OPT = "--date=$DATE"
    }

#--Check if slow queriers are enabled
$SLOW = (Invoke-MySQL -site $SID -query "show variables like 'slow_query_log';").value
if (!$SLOW)
    {
       $SLOW = (Invoke-MySQL -site $SID -query "show variables like 'log_slow_queries';").value 
    }
#--Check slow query log path
$SLOWLOG = (Invoke-MySQL -site $SID -query "show variables like 'slow_query_log_file';").value
if (!$SLOWLOG)
    {
       $SLOWLOG = (plink -i M:\scripts\sources\ts01_privkey.ppk root@$DBCLUST "cat /$HA/site$SID/mysql/my.ini|grep log_slow_queries").split('=')[1]
    }
#--Check if log_output is set to 'TABLE'
$LOG_OUTPUT = (Invoke-MySQL -site $SID -query "show variables like 'log_output';").value

if ($SLOWLOG -ne "/$HA/site$SID/mysql/slow_query.log")
    {
        
    }



if ($ENABLE)
    {
        if ($SLOW -eq 'OFF')
            {
                if ((Invoke-MySQL -site $SID -query "show variables like 'version';").value -ge '5.6')
                    {
                        Write-Host "~: Enabling slow query logging..."
                        Invoke-MySQL -site $SID -update -query "set global slow_query_log = 1;"
                    }
                        else
                            {
                                Write-Host "~: MySQL must be 5.6 or higher to enable automatically."
                            }
            }
    }
#--run slog_analyze on target database server

Write-Host -NoNewline "~: Slow Query Logs are: "
if ($SLOW -eq 'ON')
    {
        write-host -ForegroundColor Green '[ON]'
    }
        else
            {
                write-host -ForegroundColor Red '[OFF]'
            }
#Write-Host "~: Slow query log file: $SLOWLOG"
write-host "~: Checking slow query logs for site$SID on $SLAVE $DBCLUST"
if ($LOG_OUTPUT -eq 'FILE')
    {
        $SLOWLOGS = plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$DBCLUST /scripts/slog_analyze --site=$SID $OPT
    }
        else
            {
                $SLOWLOGS = Invoke-MySQL -Site $SID -Query "select start_time,user_host,query_time,lock_time,rows_sent,rows_examined,db,sql_text from mysql.slow_log where start_time like '$DATE%';"
            }

function GetStringBetweenTwoStrings($firstString, $secondString, $importPath){

    #Get content from file
    $file = $importPath

    #Regex pattern to compare two strings
    $pattern = "$firstString(.*?)$secondString"

    #Perform the opperation
    $result = [regex]::Match($file,$pattern).Groups[1].Value

    #Return result
    return $result

}

if ($FORMATTABLE -and $LOG_OUTPUT -ne 'TABLE')
    {
$SLOWQUERIES = @()
foreach ($TIME in $SLOWLOGS|Select-String '# Time:')
    {
        $QUERYTIMEPERIOD = New-Object System.Object
        $Q_ENDTIME = ($TIME).tostring()
        $dd = ($Q_ENDTIME.split(' ')[-2]).substring(4,2)
        $MM = ($Q_ENDTIME.split(' ')[-2]).substring(2,2)
        $yy = ($Q_ENDTIME.split(' ')[-2]).substring(0,2)
        $hours = $Q_ENDTIME.split(' ')[-1]
        $DATETIME = Get-Date "20$yy/$mm/$dd $hours" -Format 'yyyy-MM-dd HH:mm:ss' 
        $Q_QUERY = (GetStringBetweenTwoStrings -firstString "$TIME" -secondString '# Time:' -importPath $SLOWLOGS) -split '(?=\#)'
        $USERS = @()
        foreach ($USER in $Q_QUERY|Select-String '# User')
            {
                $Q_USER2 = $USER
                $Q_USER1 = ((($Q_USER2).tostring()).split('[')[1]).split(']')[0]
                $Q_USERIP = ((($Q_USER2).tostring()).split('[')[-1]).split(']')[0]
                $Q_USER = $Q_USER1 + '@' + $Q_USERIP
                $USERS += $Q_USER
            }
        $SCHEMAS = @()
        foreach ($SCHEMA in $Q_QUERY|Select-String '# Schema')
            {
                $SCHEMA = $SCHEMA.tostring()
                $SCHEMA = ($SCHEMA).split(' ')[2]
                $SCHEMAS += $SCHEMA
            }
        $SCHEMAS = $SCHEMAS|sort -Unique
        $QUERY_TIME = @()
        foreach ($Q_TIME in $Q_QUERY|Select-String '# Query_time')
            {
                # Query_time: 14.617125 Lock_time: 0.000040 Rows_sent: 0 Rows_examined: 1 Rows_affected: 1
                $QUERYSTATS = New-Object System.Object
                $Q_TIME = ($Q_TIME).tostring()
                $Q_DUR = ($Q_TIME).split(' ')[2]
                $Q_DUR = [math]::Round($Q_DUR)
                $LOCK_TIME = ($Q_TIME).split(' ')[4]
                $ROWS_SENT = ($Q_TIME).split(' ')[6]
                $ROWS_EXAMINED = ($Q_TIME).split(' ')[8]
                $ROWS_AFFECTED = ($Q_TIME).split(' ')[10]
                $QUERYSTATS | Add-Member -Type NoteProperty -Name Duration -Value $Q_DUR
                $QUERYSTATS | Add-Member -Type NoteProperty -Name Lock_time -Value $LOCK_TIME
                $QUERYSTATS | Add-Member -Type NoteProperty -Name Rows_Sent -Value $ROWS_SENT
                $QUERYSTATS | Add-Member -Type NoteProperty -Name Rows_Examined -Value $ROWS_EXAMINED
                $QUERYSTATS | Add-Member -Type NoteProperty -Name Rows_Affected -Value $ROWS_AFFECTED
                $QUERY_TIME += $QUERYSTATS
            }
        if ($Q_QUERY|Select-String '# Bytes')
            {
                $BYTES = @()
                foreach ($BYTE in $Q_QUERY|Select-String '# Bytes')
                    {
                        $BYTE= ($BYTE).tostring()
                        $BYTES += ($BYTE).split(' ')[2]
                    }
                $QUERIES = @()
                foreach ($QUERY in $Q_QUERY|Select-String '# Bytes')
                    {
                        $QUERY = ($QUERY).tostring()
                        $QUERY = (($QUERY) -split ';')[-2,-1]
                        $QUERIES += $QUERY
                    }
            }
                else
                    {
                        $QUERIES = @()
                        foreach ($QUERY in $Q_QUERY|Select-String '# Query_time:')
                            {
                                $QUERY = ($QUERY).tostring()
                                $QUERY = (($QUERY) -split ';')[-2,-1]
                                $QUERIES += $QUERY
                            }

                    }
        $COUNT = $QUERIES.count
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Time -Value $DATETIME
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Count -Value $COUNT
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name User -Value $Q_USER
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Schema -Value $SCHEMAS
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Duration -Value $QUERY_TIME.duration
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name 'Rows Sent/Exam' -Value ($QUERY_TIME.rows_sent,$QUERY_TIME.rows_examined)
        if ($BYTES)
            {
                $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Bytes -Value $BYTES
            }
        $QUERYTIMEPERIOD | Add-Member -Type NoteProperty -Name Queries -Value $QUERIES
        $SLOWQUERIES += $QUERYTIMEPERIOD
    }
$SLOWQUERIES
    }
        else
            {
                $SLOWLOGS
            }