#--Populate APU Id's in control data database.

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$m_SID = $R}
        if ($L -eq '--all'){$ALL = $TRUE}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = 'True'}
    }

#--Display available options
if ($HELP -eq 'True')
    {
        [PSCustomObject] @{
        'Description' = "Populate APU ID's in control database."
        '-h|--help' = 'display available options'
        '-s|--site' = 'Specify site number(optional)'
        '--all' = 'update all apu id entries'
                        }|Format-List;exit
    }

#Write-Host "Debug: $RDPUSERNAME"

#--Get the site info from database
if ($m_SID)
    {
        $SITES = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $m_SID and status like 'a%';"
        if (!$SITES -or $SITES.status -like 'i%'){Write-Output "Site$m_SID does not exist or is inactive";exit}
    }
        else
            {
                if ($ALL)
                    {
                        $SITES = Invoke-MySQL -Site 000 -Query "select * from sitetab where status like 'a%' order by siteid;"
                    }
                        else
                            {
                                $SITES = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid > 001 and status like 'a%' and apu_id like '' or siteid > 001 and status like 'a%' and apu_id is null order by siteid;"
                            }
            }




#--Get info from the site DB
foreach ($SITE in $SITES)
    {
        #--Get the site info
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SITE.dbuser_pwd
        $APUID = (Invoke-MySQL -Site $SID -Query "select value from itemkeys where name = 'AutoUpgradeKey';").value
        write-host "DEBUG: $APUID"

        #--Update the sitetab db with the APU ID
        Write-Host -NoNewline "site$SID`: "
        if ($APUID -and (Invoke-MySQL -Site 000 -Query "select apu_id from sitetab where siteid = $SID;").apu_id -ne $APUID)
            {
                Invoke-MySQL -Site 000 -Query "update sitetab set apu_id = '$APUID' where siteid = $SID limit 1;"
            }
        if ((Invoke-MySQL -Site 000 -Query "select apu_id from sitetab where siteid = $SID;").apu_id -eq $APUID)
            {
                Write-Host -ForegroundColor Green "[OK]"
            }
                else
                    {
                        Write-Host -ForegroundColor Red "[FAIL]"
                    }

    }