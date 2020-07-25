
#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '--maxpermsize' -or $L -eq '-mps' ){$PERM = $R}
            if ($L -eq '--PROCEED' -or $L -eq '-y' ){$PROCEED = $TRUE}
            if ($L -eq '--help' -or $L -eq '-h' ){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Set permgen allocation on both application tomcats. Defaults to 256MB"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--maxpermsize|-mps' = "Specify the permgen allocation numerically. Defaults to 256"
'--PROCEED|-y' = "Proceed automatically"
                }|Format-List; exit
            }

if (!$PERM){$PERM = '256'}
$NEWPERMSTRING = '-XX:MaxPermSize' + '=' + $PERM + 'M'
$NEWPERM = $PERM + 'M'

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $m_SID;"

#--Get the tomcat info
$APPCLID = $SHOW.app_cluster_id[0]
$APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCLID;"
$APP1 = $APPID.a1
$APP2 = $APPID.a2

#--Get the appserver tomcats
if (Test-Path \\$APP1\site$m_SID\tomcat8) { $m_APP1TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP1\site$m_SID\tomcat7) { $m_APP1TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP1\site$m_SID\tomcat6) { $m_APP1TOMCATDIR = 'tomcat6' }
                        }
                }
if (Test-Path \\$APP2\site$m_SID\tomcat8) { $m_APP2TOMCATDIR = 'tomcat8' }
            else
                {
                    if (Test-Path \\$APP2\site$m_SID\tomcat7) { $m_APP2TOMCATDIR = 'tomcat7' }
                    else 
                        {
                            if (Test-Path \\$APP2\site$m_SID\tomcat6) { $m_APP2TOMCATDIR = 'tomcat6' }
                        }
                }


#--Get the existing permgen value from tomcat A

$APP1PERM = get-content \\$APP1\site$m_SID\$m_APP1TOMCATDIR\conf\tomcat-env.sh|Select-String '-XX:MaxPermSize'|Out-String
#$APP1PERM = $APP1PERM.split(' ')
$APP1PERMVAL = $APP1PERM.split('=')[1]
$APP1PERMVAL = $APP1PERMVAL.split(' ')[0]
$OLDPERMSTRING = '-XX:MaxPermSize' + '=' + $APP1PERMVAL

[PSCustomObject] @{
  Site     = $m_SID
  Appserver= $APP1, $APP2 
  Old_Perm = $APP1PERMVAL, $OLDPERMSTRING
  New_Perm = $NEWPERM, $NEWPERMSTRING
} | Format-list

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Updating Permgen..."}

if ($APP1PERMVAL -like "*$PERM*"){write-host "MaxPermSize already set $APP1PERM";exit}
    else
        {
            plink.exe -i \scripts\sources\ts01_privkey.ppk root@$APP1 "cd /alley/site$m_SID/$m_APP1TOMCATDIR/conf;sed -i 's/$OLDPERMSTRING/$NEWPERMSTRING/g' tomcat-env.sh;rsync -avh tomcat-env.sh $APP2`:/alley/site$m_SID/$m_APP2TOMCATDIR/conf/"
        }