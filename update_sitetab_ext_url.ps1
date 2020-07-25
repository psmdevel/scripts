#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($ARG -eq '--all') {$ALL = $TRUE}
        if ($L -eq '--help' -or $L -eq '-h') {$HELP = $TRUE}
    }

#--Display available options
if ($HELP)
    {
        [PSCustomObject] @{
        'Description' = 'Updates control database with External URL for all or specified practices'
        '-h|--help' = 'display available options'
        '-s|--site' = 'Specify site ID'
        '--all' = 'Specify all active sites'
                        }| Format-list;exit
    }

#--Get the list of sites
if ($m_SID)
    {
        $SHOW = Invoke-MySQL --site=000 --query="select * from sitetab where status like 'a%' and siteid = $m_SID;"
    }
        else
            {
                $SHOW = Invoke-MySQL --site=000 --query="select * from sitetab where status like 'a%' order by siteid;"
            }

#--Loop through the list of sites and update the ext_url field if necessary
foreach ($s in $SHOW)
    {
        $SID = $s.siteid
        $EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01b "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"
        if ($EXTURL)
            {
                $TEST1 = (Invoke-MySQL --site=000 --query="select ext_url from sitetab where siteid = $SID;").ext_url
                if ($TEST1 -ne $EXTURL)
                    {
                        Write-Host -NoNewline "Updating sitetab ext_url for site$SID`: "
                        Invoke-MySQL --site=000 --query="update sitetab set ext_url = '$EXTURL' where siteid = $SID limit 1;"
                        $TEST2 = (Invoke-MySQL --site=000 --query="select ext_url from sitetab where siteid = $SID;").ext_url
                        if ($TEST2 -eq $EXTURL)
                            {
                                Write-Host -ForegroundColor Green '[OK]'
                            }
                                else
                                    {
                                        Write-Host -ForegroundColor Red '[FAIL]'
                                    }
                    }
                        else
                            {
                                Write-Host "Sitetab ext_url up to date for site$SID"
                            }
            }
    }