#<Function get-Auth {
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--user' -or $L -eq '-u'){$m_USER = $R}
        if ($L -eq '--pass' -or $L -eq '-p' -or $L -eq '--pwd'){$m_PWD = $R}
        if ($L -eq '--host'){$m_HOST = $R}
        if ($L -eq '--query'){$Query = $R}        
    }#>
$DRIVE = (Get-Location).Drive.Root
if (Test-Path "\\mgt01a\m$\scripts\sources\secure\256")
    {
        $KeyFile = "\\mgt01a\m$\scripts\sources\secure\256"
    }
        else
        {
            if (Test-Path "\\mgt01b\m$\scripts\sources\secure\256")
                {
                    $KeyFile = "\\mgt01b\m$\scripts\sources\secure\256"
                }
                    else
                        {
                            Write-Host "Could not access key file";exit
                        }
        }
if (Test-Path "\\mgt01a\m$\scripts\sources\secure\secret")
    {
        $PasswordFile = "\\mgt01a\m$\scripts\sources\secure\secret"
    }
        else
        {
            if (Test-Path "\\mgt01b\m$\scripts\sources\secure\secret")
                {
                    $PasswordFile = "\\mgt01b\m$\scripts\sources\secure\secret"
                }
                    else
                        {
                            Write-Host "Could not access pass file";exit
                        }
        }

# Read the secure password from a password file 
$SecurePassword = ( (Get-Content $PasswordFile) | ConvertTo-SecureString -Key (Get-Content $KeyFile) )
$Auth = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root", $SecurePassword
$Auth