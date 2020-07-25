Function Invoke-MySQL {
foreach ($ARG in $ARGS)
    {
        $L = $ARG.split('=')[0]
        $R = $ARG.split('=')[1]
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
        if ($L -eq '--host'){$HOST = $R}
        if ($L -eq '--query'){$Query = $R}
    }

$MySQLAdminUserName = 'root'
$MySQLAdminPassword = 'zrt+Axj23'
if ($SID -eq '000') 
    {$MySQLDatabase = 'control_data'
     $MySQLHost = 'dbclust11'
    } 
        else 
            {$MySQLDatabase = "mobiledoc_$SID"
             $MySQLHost = "$HOST"
            }

$MySQLPort = "5000+$SID"
$ConnectionString = "server=" + $MySQLHost + ";port=$MySQLPort;uid=" + $MySQLAdminUserName + ";pwd=" + $MySQLAdminPassword + ";database="+$MySQLDatabase

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