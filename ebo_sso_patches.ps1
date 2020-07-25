#--Applies eBO patches 3966(eBO6 & 7) & 3967(eBO7 only)

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        if ($L -eq '--table' -or $L -eq '-t' ){$TABLENAME = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = 'True'}
    }

#--Display available options
if ($HELP -eq 'True')
{
    [PSCustomObject] @{
    '-s|--site' = 'specify only one site'
    '-h|--help' = 'display available options'
    } | Format-list;exit
}

If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

$EBOSRV = $SHOW.ebo_server
if (!$EBOSRV){Write-Output "Site$SID eBO Server not found";exit}

$CHECKPERM = Test-path \\$EBOSRV\admin\eBO\site$SID
if ($CHECKPERM -eq $false)
    {
        Write-Output "Cannot find ebo folder for site$SID on $EBOSRV";exit
    }
$C10 = Test-path \\$EBOSRV\admin\eBO\site$SID\c10_64
$C8 = Test-path \\$EBOSRV\admin\eBO\site$SID\c8
if ($C10 -eq $false -and $C8 -eq $false)
    {
        Write-Output "Cannot find c8 or c10_64 folder for site$SID on $EBOSRV";exit
    }

if ($C10 -eq $true -and $C8 -eq $true)
    {
        Write-Output "Found both c8 and c10_64 folder for site$SID on $EBOSRV, please clarify version on eBO server";exit
    }


if ($C10 -eq $true)
    {
        $EBOPATH = "\\$EBOSRV\admin\eBO\site$SID\c10_64"
        $CHECKCONTEXT = Get-Content $EBOPATH\tomcat\conf\server.xml|Select-String "ebo7Service"
        $CONTEXT = " </Context>
 <Context path=`"/ebo7Service`" docBase=`"ebo7Service`" reloadable=`"false`" crossContext=`"true`">
    <Environment name=`"maxExemptions`" type=`"java.lang.Integer`" value=`"15`"/>
 </Context>"
    }

<#if ($C8 -eq $true)
    {
        $EBOPATH = "\\$EBOSRV\admin\eBO\site$SID\c8"
        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$EBOSRV "/scripts/ebomgr --site=$SID --stop"
        Remove-Item $EBOPATH\webapps\p2pd\WEB-INF\classes\com\* -force -recurse

        
    }#>








[PSCustomObject] @{
    'eBO Server' = "$EBOSRV"
    'c10_64'= "$C10"
    'c8'= "$C8"
    'Context'= "$CONTEXT"
    'Check Context' = "$CHECKCONTEXT"   
    } | Format-list

    $TEST = $CHECKCONTEXT -like "*/ebo7Service*"
    $TEST
    !$TEST