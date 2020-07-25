#--Reset Support Password

#import-module m:\scripts\mysqlcontrol.psm1
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s'){$SID = $R}
        if ($L -eq '-e'){$E = $TRUE}
    }

$SHOW = Show-Site --site=$SID --tool
#$SHOW = invoke-mysql -s=000 --query="select * from sitetab where siteid = $SID;"
if (!$SHOW -or $SHOW.status -eq 'inactive'){Write-Output "Site$SID does not exist or is inactive";exit}

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd

#--check psmsupport account
if ($E)
    {
        $ECW = Invoke-MySQL -site $SID -query "select uname,uid from mobiledoc_$SID.users where uname = 'support' and status=0 and delflag=0;"
        if (!$ECW)
            {
                echo "Site$SID user 'support' may not exist or is inactive";exit
            }
    }
if (!$E)
    {    
        $PSM = Invoke-MySQL -site $SID -query "select uname,uid from mobiledoc_$SID.users where uname = 'psmsupport' and status=0 and delflag=0;"
        if (!$PSM)
            {
                echo "Site$SID user 'psmsupport' may not exist or is inactive";exit
            }
    }
#--Get user ID
if ($ECW)
    {
        $ECWUSERID = $ECW.uid
    }
$USERID = $PSM.uid

#--change the password
$PWDDATE = Get-Date -format MMdd
$CHANGEDATE = Get-Date -format yyyy-MM-dd
if ($ECW)
    {
        Invoke-MySQL -site $SID -Update -Query "update users set upwd=md5('Mobiledoc$PWDDATE') where uname = 'support' limit 1;"
        Invoke-MySQL -site $SID -Update -Query "update authenticationuserlogin set pwdchangedate = (select now()) where userid = $ECWUSERID limit 1;"
    }
if ($PSM)
    {
        Invoke-MySQL -site $SID -Update -Query "update users set upwd=md5('Mobiledoc$PWDDATE') where uname = 'psmsupport' limit 1;"
        Invoke-MySQL -site $SID -Update -Query "update authenticationuserlogin set pwdchangedate = (select now()),userlocked = 'no',userloginfailtimes = 0 where userid = $USERID limit 1;"
    }
#--Finish
if ($PSM)
    {
        echo "site$SID 'psmsupport' account password reset to: Mobiledoc$PWDDATE"
    }
if ($ECW)
    {
        echo "site$SID 'support' account password reset to: Mobiledoc$PWDDATE"
    }