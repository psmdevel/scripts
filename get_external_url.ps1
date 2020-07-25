#--Get External URL

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
    }

#--Verify the arguments
if (!$SID){Write-Host "Please specify a site number using -s=|--site=";exit}


#--Get the proxy URL from proxy01b
   $EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01b "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"

#--Show External URL
Write-Host "https://$EXTURL/mobiledoc/jsp/webemr/login/newLogin.jsp"
