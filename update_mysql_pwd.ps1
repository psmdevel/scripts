<#--DEFUNCT

<#--Update mysql user password encryption

    Finds sites using 'old_password' for the sitexxx_DbUser and updates it to 'password'
>

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L = $ARG.split('=')[0]
        $R = $ARG.split('=')[1]
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
        if ($L -eq '--whatif') {$WHATIF = '-WhatIf'}
    }



#--Test and confirm variables
If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site$SID`_DbUser"
$DBUSER2 = "`"site$SID`_DbUser`""
$DBPWD = $SHOW.dbuser_pwd
$QUERY = "select * from mysql.user where user = '$DBUSER';"

#--Test database connectivity
$MYSQLTEST = Invoke-MySQL --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'enablemedispan';"
if (!$MYSQLTEST)
    {
        echo "$QUERY"
        #echo "$DBUSER2"
        #echo "mysql -u$SID`_DbUser -p$DBPWD -h$DBCLUST -P5$SID -e="select uid from mobiledoc_$SID.users where uname like '%support';""
        plink.exe -i \scripts\sources\ts01_privkey.ppk root@store01 "echo '$QUERY'|mysql -u$DBUSER -p$DBPWD -h$DBCLUST -P5$SID"
    }
#>
