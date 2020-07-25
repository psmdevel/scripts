#--Disable second cookie checking and truncate invalidcookielogs table. Applies to sites on 6230/6233

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module M:\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($L -eq '--help' -or $L -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Disable second cookie checking and truncate invalidcookielogs table. Applies to sites on 6230/6233/6500/6522'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number. If no site specified, applies changes to all active sites."
                }|Format-List; exit
            }
#--Define the patch ID's 
$SEC_PATCHES = @(6500,6522,6951,7005,7189,8312,8313)

$SITES = @()
if ($m_SID)
    {
        $SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $m_SID and status = 'active' order by siteid;"
        $SITES += $SHOW.siteid
    }
    else
    {
        foreach ($S in (ecwversions.ps1 -v='11.40').site)
            {
                $SITES += $S
            }
        <#foreach ($SEC in $SEC_PATCHES)
            {
                $SITES += (find_enabled_patch.ps1 --patch=$SEC --status=complete).site
            }#>
        #$SITES += (find_enabled_patch.ps1 --patch=6230 --status=complete).site
        #$SITES += (find_enabled_patch.ps1 --patch=6233 --status=complete).site
        #$SITES += (find_enabled_patch.ps1 --patch=6500 --status=complete).site
        #$SITES += (find_enabled_patch.ps1 --patch=6522 --status=complete).site
    }
$SITES = $SITES|sort -Unique
$COUNT = ($SITES).count
Write-Host "Running script against $COUNT sites..."
foreach ($SITE in $SITES)
    {
        $SHOW = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SITE;"
        $SID = $SHOW.siteid
        write-host -NoNewline "Site$SID`:"
        $DBCLUST = $SHOW.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SHOW.dbuser_pwd
        Invoke-MySQL -Site $SID -Update -Query "UPDATE securitykeys SET VALUE = 'no' WHERE NAME = 'EnableSecondCookieCheck';"
        #Invoke-MySQL -Site $SID -Query "insert ignore into ecw_sessionless_url (ecw_url) values ('/mobiledoc/jsp/catalog/xml/getServerTimeStamp.jsp');"
        $TEST1 = (Invoke-MySQL -Site $SID -Query "select value from securitykeys WHERE NAME = 'EnableSecondCookieCheck';").value
        if ($TEST1 -eq 'no')
            {
                $DISABLED = $TRUE
            }
        $TEST2 = (Invoke-MySQL -Site $SID -Query "select count(*) from invalidcookielogs;").'count(*)'
            if ($TEST2 -gt 1)
                {
                    write-host -NoNewline "..truncating.. "
                    Invoke-MySQL -Site $SID -Update -Query "truncate table invalidcookielogs;"
                }
        $TEST3 = (Invoke-MySQL -Site $SID -Query "select count(*) from invalidcookielogs;").'count(*)'
        if ($DISABLED -and $TEST3 -lt 1)
            {
                
                Write-Host -ForegroundColor Green "[OK]"
            }
                else
                    {
                        #write-host -NoNewline "Site$SID`:"
                        Write-Host -ForegroundColor Red "[FAIL]"
                    }

    }