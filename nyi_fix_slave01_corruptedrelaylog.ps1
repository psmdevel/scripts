#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
        #if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        #if ($L -eq '--table' -or $L -eq '-t' ){$TABLENAME = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = 'True'}
        #if ($L -eq '--status'){$m_STATUS = $R}
        #if ($ARG -eq '--count'){$COUNT = $TRUE}
    }


#$m_SID = '775'
$SHOW = Show-Site --site=$m_SID --tool
#$SHOW = Invoke-MySQL --site=000 --query="select * from sitetab where status like 'a%' and siteid = $m_SID;"

$slave_status = Invoke-MySQL -Site $m_SID -Slave -Query "show slave status;"
$log_file = $slave_status.relay_master_log_file
$log_pos = $slave_status.exec_master_log_pos
Invoke-MySQL -Site $m_SID -Slave -Query "stop slave;"
Invoke-MySQL -Site $m_SID -Slave -Query "reset slave;"
Invoke-MySQL -Site $m_SID -Slave -Query "change master to master_log_file='$log_file', master_log_pos=$log_pos;"
Invoke-MySQL -Site $m_SID -Slave -Query "start slave;"