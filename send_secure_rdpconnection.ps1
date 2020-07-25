#--Securely email connection instructions to an eClinicalWorks representative

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
$HOSTNAME = hostname

#--Process the command-line arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
            if ($L -eq '--email'){$EMAIL = $R}
            if ($L -eq '--ticket'){$TICKET = $R}
            if ($L -eq '--ecw'){$ECW = $R}
            if ($L -eq '--instructions'){$INSTRUCTIONS = $R}
            if ($ARG -eq '--dbdetails'){$DBDETAILS = $TRUE}
            if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Display available options
if ($HELP -or !$ARGS)
    {
        [PSCustomObject] @{
        'Description' = 'Sends secure email to an eclinicalworks.com recipient containing the RDP connection details and credentials'
        '-h|--help' = 'display available options'
        '-s|--site' = 'specify site number (required)'
        '--email' = "specify email address (required)"
        '--ticket' = 'specify ConnectWise ticket number (required)'        
        '--ecw' = 'specify eCW ticket number (required)' 
        '--instructions' = 'specify any special instructions, enclose in single quotes'
        } | Format-list;exit
    }

#--verify arguments
if(!$SID)
    {
        Write-Host "Please specify site ID"
        exit
    }
if(!$EMAIL)
    {
        Write-Host "Please specify eClinicalWorks.com email address"
        exit
    }
if(!$TICKET)
    {
        Write-Host "Please specify ConnectWise ticket number"
        exit
    }
if(!$ECW)
    {
        Write-Host "Please specify eCW ticket number"
        exit
    }
if(!$INSTRUCTIONS)
    {
        $INSTRUCTIONS = '(none)'
    }

$TECH_ARRAY = @("andy@psmnv.com", "eric.robinson@psmnv.com", "joe.dilorenzo@psmnv.com","ian.blauer@psmnv.com","patrick.hopson@psmnv.com")
#$TECHtmp = whoami
$TECH1 = $env:username
#$TECH1 = $TECHtmp.split('\')[1]
if ($TECH1 -eq 'allean2') {$TECH = $TECH_ARRAY[0]}
if ($TECH1 -eq 'robier') {$TECH = $TECH_ARRAY[1]}
if ($TECH1 -eq 'dilojo') {$TECH = $TECH_ARRAY[2]}
if ($TECH1 -eq 'blauia') {$TECH = $TECH_ARRAY[3]}
if ($TECH1 -eq 'hopspa') {$TECH = $TECH_ARRAY[4]}

if ($EMAIL -like '*@eclinicalworks.com')
    {
        $ToAddress = $EMAIL
    }
        else
            {
                Write-Host "please specify an eClinicalWorks.com email address";exit
            }
$FromAddress = $TECH
$SmtpServer = 'smtp.office365.com'
$SmtpPort = '587'

#--get info from control_data
$SHOW = Show-Site --site=$SID --tool
#$SHOW = Invoke-MySQL --site=000 --query="select * from sitetab where siteid = $SID and status like 'a%';"
$NAME = $SHOW.keywords
$APU = $SHOW.apu_id
$RDP_tmp = $SHOW.ts_cluster_id
$RDPADDRESS = $SHOW.rdp_cluster_name #(Invoke-MySQL --site=000 --query="select rdp_address from ts_clusters where id = $RDP_tmp;").rdp_address

$SUPPORT = Invoke-MySQL -site 000 -query "select * from resellers where reseller_id = 'ecw';"
$PASS = $SUPPORT.reseller_pwd

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
if (Test-Path "\\mgt01a\m$\scripts\sources\secure\cwmail")
    {
        $PasswordFile = "\\mgt01a\m$\scripts\sources\secure\cwmail"
    }
        else
        {
            if (Test-Path "\\mgt01b\m$\scripts\sources\secure\cwmail")
                {
                    $PasswordFile = "\\mgt01b\m$\scripts\sources\secure\cwmail"
                }
                    else
                        {
                            Write-Host "Could not access pass file";exit
                        }
        }

# Read the secure password from a password file and decrypt it to a normal readable string
$SecurePassword = ( (Get-Content $PasswordFile) | ConvertTo-SecureString -Key (Get-Content $KeyFile) )        # Convert the standard encrypted password stored in the password file to a secure string using the AES key file
#$SecurePasswordInMemory = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword);             # Write the secure password to unmanaged memory (specifically to a binary or basic string) 
#$PasswordAsString = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($SecurePasswordInMemory);              # Read the plain-text password from memory and store it in a variable
#[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($SecurePasswordInMemory);                                     # Delete the password from the unmanaged memory (for security reasons)
#$SMTPPassword = $PasswordAsString

$smtpcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "cwmail@psmnv.com", $SecurePassword #$SMTPPassword

$mailparam = @{
    To= $ToAddress
    From = 'psmsupport@psmnv.com'
    CC = $TECH
    Subject = "[PSM:SECURE] site$SID; SR#$TICKET eCW#$ECW RDP Connection"
    Body = "Name = $NAME
Site = $SID
APU = $APU
RDP = $RDPADDRESS
User = mycharts\site$SID`_s01
Pass = $PASS
Special Instructions = $INSTRUCTIONS"
    SmtpServer = $SmtpServer
    Port = $SmtpPort
    Credential = $smtpcred
}


[PSCustomObject] @{
        To= $ToAddress
        From = 'psmsupport@psmnv.com'
        CC = $TECH
        Subject = "[PSM:SECURE] site$SID; SR#$TICKET eCW#$ECW RDP Connection "
        Body = "Name = $NAME
Site = $SID
APU = $APU
RDP = $RDPADDRESS
User = mycharts\site$SID`_s01
Pass = $PASS
Special Instructions = $INSTRUCTIONS"
            }

$eventlog1 = @{
        To= $ToAddress
        From = $TECH
        Subject = "[PSM:SECURE] site$SID; SR#$TICKET eCW#$ECW RDP Connection "
        Name = $NAME
        Site = $SID
        APU = $APU
        RDP = $RDPADDRESS
        User = "mycharts\site$SID`_s01"
        'Special Instructions' = $INSTRUCTIONS
            }
$eventlog = $eventlog1.GetEnumerator()|Format-Table|Out-String
#--Confirmation from user

Write-host -NoNewline "Enter 'PROCEED' to send secure email: "
$RESPONSE = Read-Host
if ($RESPONSE -cne 'PROCEED') 
    {
        exit
    }
    
#--Log to the windows application event log
Write-EventLog -LogName "Application" -Source "Send_Secure_RdpConnection" -EventID 1 -EntryType Information -Message $eventlog

#--Send the secured email
Send-MailMessage @mailparam -UseSsl