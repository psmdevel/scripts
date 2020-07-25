#foreach ($s in query_mass_deploy.ps1 -p=6758){($s.tostring()).split('e')[-1]} #SID
#foreach ($s in query_mass_deploy.ps1 -p=6758){(($s.tostring()).split('\')[-1]).split(' ')[0]} #Tech
#foreach ($s in query_mass_deploy.ps1 -p=6758){($s.tostring()).split('-')[4]} #Hostname
#foreach ($s in query_mass_deploy.ps1 -p=6758){($s.tostring()).substring(0,19)} #Datestamp
#foreach ($s in query_mass_deploy.ps1 -p=6758){($s.tostring()).split(' ')[3]} #patch

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--patch' -or $L -eq '-p') {$m_PATCH = $R}
        if ($ARG -eq '--help') {$HELP = '-h'}
    }
#$m_PATCH = '6758'
$MASS_DEPLOYMENT = @()
foreach ($s in query_mass_deploy.ps1 --patch=$m_PATCH --nosummary)
    {
        $SID = ($s.tostring()).split('e')[-1]
        if ($SID)
            {
                $TECH = (($s.tostring()).split('\')[-1]).split(' ')[0]
                $HOSTNAME = ($s.tostring()).split('-')[4]
                $DATESTAMP = ($s.tostring()).substring(0,19)
                $PATCHID = ($s.tostring()).split(' ')[3]
                $PATCH_ITEMS = New-Object system.object
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name SiteID -Value "$SID"
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name Installer -Value "$TECH"
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name Hostname -Value "$HOSTNAME"
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name End_Time -Value "$DATESTAMP"
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name PatchID -Value "$PATCHID"
                $PATCH_ITEMS | Add-Member -Type NoteProperty -Name Status -Value "completed"
                $MASS_DEPLOYMENT += $PATCH_ITEMS
                #$PATCH_ITEMS
            }
    }

foreach ($i in $MASS_DEPLOYMENT)
    {
        $SiteID = $i.siteid
        $Installer = $i.installer
        $Hostname = $i.hostname
        $End_Time = $i.end_time
        $PatchID = $i.patchid
        $Status = $i.status
        if (-not(Invoke-MySQL --site=000 --query="select * from mass_deploy where siteid = $SiteID and patchid = $PATCHID"))
            {
                Invoke-MySQL --site=000 --query="insert into mass_deploy (siteid,end_time,patchid,status,installer,hostname) values ('$SiteID','$End_Time','$PatchID','$Status','$Installer','$Hostname');"
            }
    }