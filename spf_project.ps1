#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '-h' -or $L -eq '--help') {$HELP = '-h'}
    }

$SHOW = Show-Site --site=$SID --tool
$APP1 = $SHOW.a1
$APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
if (!$APP1_TC_VERSION)
    {
        Write-Output "could not determine tomcat version, exiting"
        exit
    }
$APP1_TC = "tomcat$APP1_TC_VERSION"
$APU = $SHOW.apu_id

if (-not(Test-Path \\$APP1\site$SID\$APP1_TC\webapps\mobiledoc\jsp\catalog\xml\specialityforms))
    {
        Write-Output "Could not access \\$APP1\site$SID\$APP1_TC\webapps\mobiledoc\jsp\catalog\xml\specialityforms, exiting"
        exit
    }
        else
            {
                Write-Output "copying \\$APP1\site$SID\$APP1_TC\webapps\mobiledoc\jsp\catalog\xml\specialityforms to N:\tmp_staging\specialityforms\$APU"
                cpi -Recurse -Force \\$APP1\site$SID\$APP1_TC\webapps\mobiledoc\jsp\catalog\xml\specialityforms N:\tmp_staging\specialityforms\$APU
                Write-Output "zipping N:\tmp_staging\specialityforms\$APU into N:\tmp_staging\specialityforms\specialityforms.zip"
                & 'M:\Program Files\7-Zip\7z.exe' a -tzip  N:\tmp_staging\specialityforms\specialityforms.zip N:\tmp_staging\specialityforms\$APU
                Write-Output "deleting local copy of $APU"
                Remove-Item -Recurse -Force N:\tmp_staging\specialityforms\$APU
            }