Function Invoke-MySQL-RO {
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--user' -or $L -eq '-u'){$m_USER = $R}
        if ($L -eq '--pass' -or $L -eq '-p' -or $L -eq '--pwd'){$m_PWD = $R}
        if ($L -eq '--host'){$m_HOST = $R}
        if ($L -eq '--query'){$Query = $R}        
    }
$DRIVE = (Get-Location).Drive.Root
if (Test-Path "$DRIVE\scripts\sources\secure\256")
    {
        $KeyFile = "\\mgt01a\m$\scripts\sources\secure\256"
    }
        else
            {
                Write-Host "Could not access key file";exit
            }
if (Test-Path "$DRIVE\scripts\sources\secure\secret_ro")
    {
        $PasswordFile = "$DRIVE\scripts\sources\secure\secret_ro"
    }
        else
            {
                Write-Host "Could not access pass file";exit
            }
        
#$PasswordFile = "\\mgt01a\m$\scripts\sources\secure\secret_ro"
#$FILEPASS = Get-Content $File|ConvertTo-SecureString -key $Key

if ($Query -notlike 'select*')
    {
        Write-Output "Only 'select' queries are allowed.";exit
    }

# Read the secure password from a password file and decrypt it to a string
$SecurePassword = ( (Get-Content $PasswordFile) | ConvertTo-SecureString -Key (Get-Content $KeyFile) )        # Convert the standard encrypted password stored in the password file to a secure string using the AES key file
$SecurePasswordInMemory = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword);             # Write the secure password to unmanaged memory (specifically to a binary or basic string) 
$PasswordAsString = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($SecurePasswordInMemory);              # Read the plain-text password from memory and store it in a variable
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($SecurePasswordInMemory);                                     # Delete the password from the unmanaged memory (for security reasons)

if (!$m_USER) {$MySQLAdminUserName = 'kiosk_ro'} else {$MySQLAdminUserName = $m_USER}
if (!$m_PWD) {$MySQLAdminPassword = $PasswordAsString} else {$MySQLAdminPassword = $m_PWD}
if ($m_SID -eq '000') 
    {
        $MySQLDatabase = 'control_data'
        $MySQLHost = 'dbclust11'
    } 
        else 
            {
                $MySQLDatabase = "mobiledoc_$m_SID"
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
write-output "DBName: $MySqlDatabase"#>
#write-output "DBPwd: $MySQLAdminPassword"
#write-output "Key: $Key"
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