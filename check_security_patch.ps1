#--Check for security patch entry in upgrade_sqlversions

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

$SHOW = invoke-mysql --site=000 --query="select * from sitetab where siteid > 001 and status = 'active' order by siteid;"
$APPLIED = New-Object System.Object
foreach ($SITE in $SHOW)
    {
        $SID = $SITE.siteid
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + "_DbUser"
        $DBPWD = $SITE.dbuser_pwd
        $TEST = invoke-mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select version from upgrade_sqlversions where version = '12142018.103';"
        if ($TEST)
            {
                write-host -NoNewline "Site$SID`:"
                Write-Host -ForegroundColor Green "[APPLIED]"
            }
                else
                    {
                        write-host -NoNewline "Site$SID`:"
                        Write-Host -ForegroundColor Red "[NOT APPLIED]"
                    }

    }