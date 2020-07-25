#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the command-line arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
            if ($L -eq '--first' -or $L -eq '-f' ){$UFNAME = $R}
            if ($L -eq '--last' -or $L -eq '-l' ){$ULNAME = $R}
            if ($L -eq '--newuser'){$NewUserTmp = $R}
            if ($L -eq '--help' -or $L -eq '-h') {$HELP = $TRUE}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = $TRUE}
    }

if ($NewUserTmp -and $UFNAME -or $NewUserTmp -and -$ULNAME)
    {
        $HELP = $TRUE
    }

#--Display available options
if ($HELP -or !$SID)
{
    [PSCustomObject] @{
    'Description' = 'Creates new RDP account for specified user and siteid'
    '-h|--help' = 'display available options'
    '-s|--site' = 'specify siteid'
    '-f|--first' = 'specify user first name'
    '-l|--last' = 'specify user last name'
    '--newuser' = 'specify username suffix. Used instead of -f/-l'
        } | Format-list;exit
}

$SHOW = Show-Site --site=$SID -tool
#$SHOW = Invoke-MySQL --site=000 --query="select * from sitetab where status like 'a%' and siteid = $SID;"
$Pass = $show.win_pwd
$Pass = ConvertTo-SecureString -String $Pass -AsPlainText -Force

$NewUserName = ($FirstName)

$RDPUSERNAMES = ($ULNAME[0..3] -join "") + ($UFNAME[0..1] -join "")
$NewUser = "site$SID`_" + $RDPUSERNAMES

#--Check if specified RDP account already exists
$ErrorActionPreference = ‘SilentlyContinue’
if (Get-ADUser -Identity $NewUser -ErrorAction SilentlyContinue)
        {
            Write-Host "RDP Account matching $NewUser exists. Exiting";exit
        }
$ErrorActionPreference = ‘Continue’

$User = Get-AdUser -Identity "site$SID`_s00"#(Read-Host "Copy From Username")
$DN = $User.distinguishedName
$OldUser = [ADSI]"LDAP://$DN"
$Parent = $OldUser.Parent
$OU = [ADSI]$Parent
$OUDN = $OU.distinguishedName
#$NewUser = Read-Host "New Username"
#$firstname = Read-Host "First Name"
#$Lastname = Read-Host "Last Name"
#$NewName = "$NewUser"
$DESCRIPTION = (Get-ADUser -Identity "site$SID`_mapper" -Properties *).description
$FirstName = (Get-Culture).TextInfo.ToTitleCase($UFNAME)
$LastName = (Get-Culture).TextInfo.ToTitleCase($ULNAME)


#--Display user details
[PSCustomObject] @{
  Site     = $SID
  FirstName = $FirstName
  LastName = $LastName
  RDPAccount = $NewUser
  } | Format-list

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = Read-Host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting install..."}


New-ADUser -SamAccountName $NewUser -Name $NewUser -UserPrincipalName ($NewUser + "@mycharts.md") -GivenName $FirstName -Surname $LastName -Description "$DESCRIPTION" -Instance $DN -Path "$OUDN" -AccountPassword $Pass -ChangePasswordAtLogon $TRUE -Enabled $TRUE -DisplayName ($FirstName + ' ' + $LastName)
<#foreach ($g in (Get-ADPrincipalGroupMembership "site$SID`_s00").name)
    {
        Add-ADGroupMember -Identity 'Remote Desktop Users' -Members $NewUser
        Add-ADGroupMember -Identity 'Domain-Wide Terminal Services Users' -Members $NewUser
        Add-ADGroupMember -Identity ((Get-ADPrincipalGroupMembership "site$SID`_s00"|select name).name)[-1] -Members $NewUser
    }#>
Add-ADGroupMember -Identity 'Remote Desktop Users' -Members $NewUser
Add-ADGroupMember -Identity 'Domain-Wide Terminal Services Users' -Members $NewUser
Add-ADGroupMember -Identity ((Get-ADPrincipalGroupMembership "site$SID`_s00"|where {$_.name -like "site$SID*"}|select name).name) -Members $NewUser