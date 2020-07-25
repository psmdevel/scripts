#--Zip signatures

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$SID = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
    }


$SHOW = Show-Site --site=$SID --tool
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$KeyWords = $SHOW.keywords
$APP1_TC_VERSION = Connect-Ssh -ComputerName $APP1 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
if (!$APP1_TC_VERSION)
    {
        $APP2_TC_VERSION = Connect-Ssh -ComputerName $APP2 -ScriptBlock "ls -1 /alley/site$SID|grep tomcat|sort|sed 's/tomcat//g'|head -1"
        if (!$APP2_TC_VERSION)
            {
                Write-Output "could not determine tomcat version, exiting"
                exit
            }
    }
        
if (-not(Test-Path \\$APP1\site$SID\))
    {
        $APP_TC = "tomcat$APP2_TC_VERSION"
        $APP = $APP2
    }
        else
            {
                $APP_TC = "tomcat$APP1_TC_VERSION"
                $APP = $APP1
            }
$APU = $SHOW.apu_id

$Providers = (Invoke-MySQL -Site $SID -Query "select uname from users where usertype = 1 and delflag = 0 and status = 0;").uname
md N:\tmp_staging\signatures\$SID`_$KeyWords|Out-Null
if (-not(Test-Path \\$APP\site$SID\$APP_TC\webapps\mobiledoc\practicedata\catalogimages\))
    {
        Write-Output "Could not access \\$APP\site$SID\$APP_TC\webapps\mobiledoc\practicedata\catalogimages\, exiting"
        exit
    }
        else
            {
                foreach ($User in $Providers)
                    {
                        $UserJpg = "$User.jpg"
                        if (Test-Path \\$APP\site$SID\$APP_TC\webapps\mobiledoc\practicedata\catalogimages\$UserJpg)
                            {
                                Write-Output "copying $UserJpg"
                                cpi \\$APP\site$SID\$APP_TC\webapps\mobiledoc\practicedata\catalogimages\$UserJpg N:\tmp_staging\signatures\$SID`_$KeyWords\
                            }
                                else
                                    {
                                        Write-Output "could not find $UserJpg"
                                    }

                    }
                Write-Output "zipping $SID`_$KeyWords"
                & 'M:\Program Files\7-Zip\7z.exe' a -tzip  N:\tmp_staging\signatures\signatures.zip N:\tmp_staging\signatures\$SID`_$KeyWords
                Write-Output "deleting local copy of $SID`_$KeyWords"
                Remove-Item -Recurse -Force N:\tmp_staging\signatures\$SID`_$KeyWords
            }