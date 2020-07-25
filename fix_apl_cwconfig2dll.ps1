#--Copy new Cwconfig2.dll to RDP client folder

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = 'True'}
        #if ($L -eq '-a'){$A = 'True'}
        #if ($L -eq '-b'){$B = 'True'}
    }

#--Display available options
if ($HELP)
{
    [PSCustomObject] @{
    'Description' = "Applies security dll fix for APL reports to the terminal servers for the specified site"
    '-h|--help' = 'display available options'
    '-s|--site' = 'Specify the site number'
    } | Format-list;exit
}

#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
#if ($A -and $B){write-host "Please specify either -a or -b, but not both";exit}

#--Query the Control Data DB for the site info
if ($SID) {$SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SID;"}
if ($SHOW.status -eq 'inactive'){Write-Host "Site is inactive. Please try an active site";exit}

#--Get the terminal server info
$TSCID = $SHOW.ts_cluster_id[0]
$TSID = Invoke-MySQL -Site 000 -Query "select * from ts_clusters where id = $TSCID;"
$TS1 = $TSID.t1
$TS2 = $TSID.t2
$TSR1 = Invoke-MySQL -Site 000 -Query "select * from ts_properties where name = '$TS1';"
#$TSR2 = Invoke-MySQL -Site 000 -Query "select * from ts_properties where name = '$TS2';"
$TS_ROOT = $TSR1.site_root.split(':')[0]
#write-host "DEBUG: TSCID - $TSCID"
#write-host "DEBUG: TS1 - $TS1"
#write-host "DEBUG: TS2 - $TS2"
#write-host "DEBUG: TS_ROOT - $TS_ROOT"

$TEST1 = Test-Path \\$TS1\$TS_ROOT$\sites\$SID
if ($TEST1 -eq $TRUE)
    {
        $TS = $TS1
    }
        else
            {
                $TEST2 = Test-Path \\$TS2\$TS_ROOT$\sites\$SID
                if ($TEST2 -eq $TRUE)
                    {
                        $TS = $TS2
                    }
                        else
                            {
                                write-host "Could not access either terminal server folder";exit
                            }
            }
            
$TSR1 = Invoke-MySQL -Site 000 -Query "select * from ts_properties where name = '$TS';"
#Write-Host "Debug: TSR1 = $TSR1"
#$TSR2 = $TSR.site_root
#Write-Host "Debug: TSR2 = $TSR2"
$TS_ROOT = $TSR1.site_root.split(':')[0]
#Write-Host "Debug: TSR_ROOT = $TS_ROOT"


$TEST3 = Test-Path "\\$TS\$TS_ROOT$\sites\$SID\Program Files\eClinicalWorks"
if ($TEST3 -eq $FALSE)
    {
        write-host "Could not access eClinicalWorks client folder";exit
    }
        else
            {
                #--Test size of CwConfig2.dll
                $CWCTEST1 = gci "\\$TS\$TS_ROOT$\sites\$SID\Program Files\eClinicalWorks\CwConfig2.dll"
                if ($CWCTEST1.Length -eq '180224')
                    {
                        write-host -NoNewline "CwConfig2.dll already updated. "
                        Write-Host -ForegroundColor Green "[OK]";exit
                    }
                if ($CWCTEST1.Length -lt '180224')
                    {
                        write-host -NoNewline "Copying CwConfig2.dll to $TS"
                        cpi -Force M:\scripts\PatchCentral\patches\patch_0036\client\CwConfig2.dll "\\$TS\$TS_ROOT$\sites\$SID\Program Files\eClinicalWorks\"
                        $CWCTEST2 = gci "\\$TS\$TS_ROOT$\sites\$SID\Program Files\eClinicalWorks\CwConfig2.dll"
                        if ($CWCTEST2.Length -eq '180224')
                            {
                                Write-Host -ForegroundColor Green "[OK]"
                            }
                                else
                                    {
                                        $CWC2SIZE = $CWCTEST2.Length
                                        Write-Host -ForegroundColor Red "[FAILED]Size: $CWC2SIZE"
                                    }
                    }
            }
    