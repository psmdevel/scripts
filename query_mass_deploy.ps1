#--Checks the mass_deploy status for a patch

#--import sql module
Import-Module SimplySql
$Auth = get-Auth.ps1

#--Loop through the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '-s' -or $L -eq '--site'){$m_SID = $R}
        if ($L -eq '-p' -or $L -eq '--patch'){$PATCH = $R}
        if ($L -eq '--support'){$m_SUPPORT = $R}
        #if ($L -eq '--count'){$COUNT = $TRUE}
        if ($L -eq '--failed'){$FAIL = $TRUE}
        if ($L -eq '--initiated'){$INITIATE = $TRUE}
        if ($L -eq '--nosummary'){$NOSUMMARY= $TRUE}
        if ($L -eq '--report'){$REPORT = $TRUE}
        if ($ARG -eq '-h' -or $ARG -eq '--help'){$HELP = $TRUE}
    }

#--Sanity check support provider if specified
$PROVIDERS = @('psm','ecw','gohs','ero','cps')
if ($m_SUPPORT)
    {
        if ($PROVIDERS -notcontains $m_SUPPORT)
            {
                Write-Host "Invalid support provider specified"
                $HELP = $TRUE
            }
    }
if (!$PATCH -and !$m_SID)
    {
        $HELP = $TRUE
    }     
#--Display available options
if ($HELP -or !$ARGS)
{
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s|--site' = 'set site number'
    '-p|--patch' = 'specify which patch to query against'
    '--support' = 'specify support provider, psm|ecw|gohs|ero|cps'
    #'--count' = 'get the number of completed sites'
    } | Format-list;exit
}

#--Make sure a patch number was specified
#if (!$PATCH){Write-Host "Please specify a patch number to query using -p= or --patch=";exit}

   


#--Set the log file to query
#$LOG = "\\mgt01a\m$\scripts\patchcentral\temp\mass_deployment\$PATCH\mass_deploy_$PATCH.txt"
Open-MySqlConnection -Server dbclust11 -Port 5000 -Database control_data -Credential $Auth
#--Set Success and Failure counts
if ($m_SID -and !$PATCH)
    {
        $MD = Invoke-SqlQuery -query "select md.siteid,s.apu_id,s.keywords,md.end_time,md.patchid,md.status,md.installer,md.hostname,s.support_id from mass_deploy md inner join sitetab s on md.siteid = s.siteid where s.siteid = $m_SID and md.status = 'completed' and md.end_time not like '0000%';"
    }
        else
            {
                $MD = Invoke-SqlQuery -query "select md.siteid,s.apu_id,s.keywords,md.end_time,md.patchid,md.status,md.installer,md.hostname,s.support_id from mass_deploy md inner join sitetab s on md.siteid = s.siteid where md.patchid = $PATCH and md.end_time not like '0000%';"
            }
<#if ($FAIL)
    {
        $FAILED = Invoke-MySQL --site=000 --query="select siteid,patchid,status,end_time,installer,hostname from mass_deploy where patchid = $PATCH and status = 'failed';"
    }
if ($INITIATE)
    {
        $INITIATED = Invoke-MySQL --site=000 --query="select siteid,patchid,status,start_time,installer,hostname from mass_deploy where patchid = $PATCH and status = 'initiated';"
    }#>
#$MD = Get-Content $LOG|Select-String  "patch $PATCH applied to site"|Sort-Object -Unique #|Get-Unique
#$FAILED = get-content $LOG|Select-String "Patch $PATCH failed for site"
Close-SqlConnection


if ($m_SID)
    {
        $NOSUMMARY = $TRUE
        $OUTPUT1 = $MD |where {$_.siteid -eq $m_SID}|select siteid,apu_id,end_time,patchid,status,installer,hostname,support_id
        $OUTPUT3 = $OUTPUT1 
        if (!$OUTPUT1)
            {
                $OUTPUT1 = $FAILED |where {$_.siteid -eq $m_SID}
                if (!$OUTPUT1)
                    {
                        $OUTPUT1 = "Patch_$PATCH not applied to site$m_SID via mass deploy tool"
                    }
            }
    }
if ($m_SUPPORT)
    {
        $MD = $MD |where {$_.support_id -eq "$m_SUPPORT"}
    }


if (!$m_SID)
    {
        $OUTPUT2 = $MD.count
        $OUTPUT3 = $MD|Select-Object siteid,apu_id,end_time,patchid,status,installer,hostname,support_id}

if ($FAIL)
    {
        $OUTPUT2 = ($MD|where {$_.status -eq 'failed'}).count
        $OUTPUT3 = $MD|where {$_.status -eq 'failed'}
    }

if ($INITIATE)
    {
        $OUTPUT2 = ($MD|where {$_.status -eq 'initiated'}).count
        $OUTPUT3 = $MD|where {$_.status -eq 'initiated'}
    }

<#if ($OUTPUT1)
    {
       $OUTPUT3 = $OUTPUT1|select siteid,apu_id,start_time,end_time,patchid,status,installer,hostname,support_id     
    }#>
if ($REPORT)
            {
                $OUTPUT3 = $MD|Select-Object siteid,apu_id,keywords,end_time,patchid,status,support_id
            }
#$OUTPUT2
$OUTPUT3
if (!$FAIL)
    {
        if (!$NOSUMMARY -and !$INITIATE)
            {
                Write-Host "Patch $PATCH mass deployed to $OUTPUT2 sites"
            }
    }
        else
            {
                if ($INITIATE)
                    {
                        Write-Host "Patch $PATCH initiated on $OUTPUT2 sites"
                    }
                        else
                            {
                                Write-Host "Patch $PATCH failed on $OUTPUT2 sites"
                            }
            }