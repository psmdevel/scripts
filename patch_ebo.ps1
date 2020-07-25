#--Applies eBO patches

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force


foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
        if ($L -eq '--patch' -or $L -eq '-p' ){$PATCH = $R}
        #if ($L -eq '--table' -or $L -eq '-t' ){$TABLENAME = $R}
        if ($L -eq '--help' -or $L -eq '-h' ){$HELP = 'True'}
        #if ($L -eq '--status'){$m_STATUS = $R}
        #if ($ARG -eq '--count'){$COUNT = $TRUE}
    }

#--Confirm eBO patch exists
$eBOPATH = "$DRIVE\scripts\PatchCentral\patches\patch_$PATCH\ebo_server"
$eBOTEST = Test-Path M:\scripts\PatchCentral\patches\patch_$PATCH\ebo_server -PathType Container
if (!$eBOTEST)
    {
        Write-Host "Patch specified is not an eBO patch or does not exist";exit
    }
#--Test if WAR files exist for patch
$eBOWARTEST = Test-Path M:\scripts\PatchCentral\patches\patch_$PATCH\ebo_server\webapps\*.war
if ($eBOWARTEST)
    {
        $WARFILES = $TRUE
    }

#--Get the site info
$SHOW = Show-Site --site=$m_SID --tool
#$SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where siteid=$m_SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"

#--Get the eBO info
$COGNOS = $SHOW.ebo_server
if (!$COGNOS)
    {
        Write-Host "eBO Server does not exist for site$m_SID";exit
    }

#--Confirm practice is on eBO7
$C10 = Connect-Ssh -ComputerName $COGNOS -ScriptBlock "find /eBO/site$m_SID -maxdepth 1 -name c10_64"

[PSCustomObject] @{
'siteid' = "$m_SID"
'patch' = "$PATCH"
'eBO Server' = $COGNOS
'eBO Path' = "$C10"
'WAR Files' = $WARFILES
        }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to continue: "
        $RESPONSE = read-host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Starting upgrade..."}

#--Stop eBO service
ebomgr --site=$m_SID --stop

#--Clear logs and temp folders
Write-Output "Clearing /$C10/logs/"
Connect-Ssh -ComputerName $COGNOS -ScriptBlock "find /$C10/logs -exec rm -f {} \; "
Write-Output "Clearing /$C10/temp/"
Connect-Ssh -ComputerName $COGNOS -ScriptBlock "find /$C10/temp -exec rm -rf {} \; "

#--Copy eBO files
Send-Scp -ComputerName $COGNOS -LocalFile $DRIVE\scripts\patchcentral\patches\patch_$PATCH\ebo_server\webapps -RemoteFile /$C10/

#--Check if extracted WAR Folders need to be removed
if ($WARFILES)
    {
        foreach ($W in gci -name $eBOPATH\webapps\*.war)
            {
                $W = $W.split('.')[0]
                $WAR = Connect-Ssh -ComputerName $COGNOS -ScriptBlock "find $C10/webapps -maxdepth 1 -type d -name $W;"
                if ($WAR)
                    {
                        Write-Host -NoNewline "Remove WAR Folder: $W..."
                        Connect-Ssh -ComputerName $COGNOS -ScriptBlock "find $C10/webapps -maxdepth 1 -type d -name $W -exec rm -rf {} \;"
                        Write-Host " Done."

                    }
            }
    }

#--Start eBO Service
ebomgr --site=$m_SID --start
    