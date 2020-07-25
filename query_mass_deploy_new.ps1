#--Checks the mass_deploy status for a patch

#--Loop through the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '-s' -or $L -eq '--site'){$SID = $R}
        if ($L -eq '-p' -or $L -eq '--patch'){$PATCH = $R}
        if ($L -eq '--count'){$COUNT = 'True'}
        if ($L -eq '--failed'){$FAIL = 'True'}
        if ($L -eq '--nosummary'){$NOSUMMARY= $TRUE}
        if ($ARG -eq '-h' -or $ARG -eq '--help'){$HELP = 'True'}
    }

#--Display available options
if ($HELP -eq 'True' -or !$ARGS)
{
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s|--site' = 'set site number'
    '-p|--patch' = 'specify which patch to query against'
    '--count' = 'get the number of completed sites'
    } | Format-list;exit
}

#--Make sure a patch number was specified
if (!$PATCH){Write-Host "Please specify a patch number to query using -p= or --patch=";exit}


#--Set the log file to query
$LOG = "\\mgt01a\m$\scripts\patchcentral\temp\mass_deployment\$PATCH\mass_deploy_$PATCH.txt"

#--Set Success and Failure counts
$SUCCESS = Invoke-MySQL --site=000 --query="select siteid,patchid,status,end_time,installer,hostname from mass_deploy where patchid = $PATCH and status = 'completed';"
$FAILED = Invoke-MySQL --site=000 --query="select siteid,patchid,status,end_time,installer,hostname from mass_deploy where patchid = $PATCH and status = 'failed';"
#$SUCCESS = Get-Content $LOG|Select-String  "patch $PATCH applied to site"|Sort-Object -Unique #|Get-Unique
#$FAILED = get-content $LOG|Select-String "Patch $PATCH failed for site"


if ($SID)
    {
        $NOSUMMARY = $TRUE
        $OUTPUT1 = $SUCCESS |where {$_.siteid -eq $SID}
        if (!$OUTPUT1)
            {
                $OUTPUT1 = $FAILED |where {$_.siteid -eq $SID}
                if (!$OUTPUT1)
                    {
                        $OUTPUT1 = "Patch_$PATCH not applied to site$SID via mass deploy tool"
                    }
            }
    }



if (!$SID)
    {
        $OUTPUT2 = $SUCCESS.count
        $OUTPUT3 = $SUCCESS}

if ($FAIL)
    {
        $OUTPUT2 = $FAILED.count
        $OUTPUT3 = $FAILED
    }


if ($OUTPUT1)
    {
        $OUTPUT1|ft
    }
#$OUTPUT2
$OUTPUT3|ft
if (!$FAIL)
    {
        if (!$NOSUMMARY)
            {
                Write-Host "Patch $PATCH mass deployed to $OUTPUT2 sites"
            }
    }
        else
            {
                Write-Host "Patch $PATCH failed on $OUTPUT2 sites"
            }