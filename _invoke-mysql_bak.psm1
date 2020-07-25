Function Invoke-MySQL {
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--user' -or $L -eq '-u'){$m_USER = $R}
        if ($L -eq '--pass' -or $L -eq '-p'){$m_PWD = $R}
        if ($L -eq '--host'){$m_HOST = $R}
        if ($L -eq '--query'){$Query = $R}        
    }



if (!$m_USER) {$MySQLAdminUserName = 'root'} else {$MySQLAdminUserName = $m_USER}
if (!$m_PWD) {$MySQLAdminPassword = 'zrt+Axj23'} else {$MySQLAdminPassword = $m_PWD}
if ($m_SID -eq '000') 
    {$MySQLDatabase = 'control_data'
     $MySQLHost = 'dbclust11'
    } 
        else 
            {$MySQLDatabase = "mobiledoc_$m_SID"
             $MySQLHost = "$m_HOST"
            }

$MySQLPort = "5$m_SID"
$ConnectionString = "server=" + $MySQLHost + ";port=$MySQLPort;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase
<#--Testing
write-output "SiteID: $m_SID"
write-output "Host: $m_HOST"
write-output "Query: $Query"
write-output "Port: $MySQLPort"
write-output "String: $ConnectionString"
write-output "DBName: $MySqlDatabase"
#>


Try {
  [void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
  $Connection = New-Object MySql.Data.MySqlClient.MySqlConnection
  $Connection.ConnectionString = $ConnectionString
  $Connection.Open()

  $Command = New-Object MySql.Data.MySqlClient.MySqlCommand($Query, $Connection)
  $DataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($Command)
  $DataSet = New-Object System.Data.DataSet
  $RecordCount = $dataAdapter.Fill($dataSet, "data")
  $DataSet.Tables[0]
  }

Catch {
  Write-Host "ERROR : Unable to run query : $query `n$Error[0]"
 }

Finally {
  $Connection.Close()
  }
}