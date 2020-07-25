#--Populates new_install_summary.txt

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$SID = [INT]$R}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Generate installation summary for a specified site"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
                }|Format-List; exit
            }

#--Get data from sitetab
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"

#--Get info from the site DB
$DBCLUST = $SHOW.db_cluster
$DBUSER = "site" + $SID + "_DbUser"
$DBPWD = $SHOW.dbuser_pwd
$DSNPWD = $SHOW.dsn_pwd
#$DBSTRING = "--site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD"
#Write-Output "DEBUG: DBUSER = $DBUSER"
#Write-Output "DEBUG: DBPWD = $DBPWD"
#Write-Output "DEBUG: DBSTRING = $DBSTRING"
$FACILITY = Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from edi_facilities where PrimaryFacility = 1 limit 1;"
$FACILITYNAME = $FACILITY.name
$PROVIDER1 = Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select uname,ufname,ulname,initials from users where uid = 122;"
$ECWLOGIN1 = $PROVIDER1.uname
$PROV1NAME = $PROVIDER1.ufname + ' ' + $PROVIDER1.ulname + ',' + ' ' + $PROVIDER1.initials
$VER = Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select * from itemkeys where name = 'ClientVersion'"
$VERSION = $VER.value


#--Get External URL
$EXTURL =  plink.exe -i \scripts\sources\ts01_privkey.ppk root@proxy01b "ls -1 /etc/nginx/conf.d|grep site$SID|sed s/.conf//g"

#--Get subnet
if ($SID -ge 001 -and $SID -lt 256) {$B = 16;$C = $SID;$SUBNET = "172.$B.$C.0/26"}
if ($SID -ge 256 -and $SID -lt 512) {$B = 18;$C = $SID - 256;$SUBNET = "172.$B.$C.0/26"}
if ($SID -ge 512 -and $SID -lt 768) {$B = 19;$C = $SID - 512;$SUBNET = "172.$B.$C.0/26"}
if ($SID -ge 768 -and $SID -lt 1024) {$B = 20;$C = $SID - 768;$SUBNET = "172.$B.$C.0/26"}
$SID -eq [INT]
echo "DEBUG B: $B"
echo "DEBUG C: $C"
echo "DEBUG SUBNET: $SUBNET"

#--Get Support login ID
$RESELLER = $SHOW.reseller_id
$RESELLERID = Invoke-MySQL -s=000 --query="select * from resellers where reseller_id = '$RESELLER';"
$RESELLRDPID = $RESELLERID.reseller_slot
#Write-Host "DEBUG: Reseller code: $RESELLRDPID"
#Write-Host "DEBUG: Reseller code: $RESELLID"

#--Copy the Checklist Summary Template and replace variables
Copy-Item -Path M:\scripts\sources\new_installs\install_summary_template.txt -Destination M:\scripts\sources\new_installs\site$SID`_summary.txt


if (Test-Path M:\scripts\sources\new_installs\site$SID`_summary.txt)
    {
        Replace-FileString.ps1 -pattern '###' -replacement $SID -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxpracticenamexx' -replacement $FACILITYNAME -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxchromexx' -replacement $EXTURL -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxapuidxx' -replacement $SHOW.apu_id -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxprovidernamexx' -replacement $PROV1NAME -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxecwloginxx' -replacement $ECWLOGIN1 -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxhidsnxx' -replacement $DBPWD -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxlodsnxx' -replacement $DSNPWD -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxsubnetxx' -replacement $SUBNET -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxYYxx' -replacement $RESELLRDPID -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
        Replace-FileString.ps1 -pattern 'xxversionxx' -replacement $VERSION -path M:\scripts\sources\new_installs\site$SID`_summary.txt -overwrite
    }
        else
            {Write-Host "Template copy failed";exit}

Write-host "Done. Opening summary document"
notepad M:\scripts\sources\new_installs\site$SID`_summary.txt
exit

