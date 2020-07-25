#--Find inactive eBO instances on all eBO servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}#;If (!$SID) {write-output "No Site ID specified. Please use --site= or -s="; exit}
            if ($ARG -eq '--help' -or $ARG -eq '-h' ){$HELP = $TRUE}
            if ($ARG -eq '--remove' -or $ARG -eq '--delete'){$REMOVE = $TRUE}
            #if ($ARG -eq '--force' -or $ARG -eq '-f' ){$FORCE = $TRUE}
            #if ($L -eq '--cluster' ){$CLUSTER = $R}
            #if ($L -eq '--proceed' -or $L -eq '-y' ){$PROCEED = $TRUE}
    }

#--Display available options
if ($HELP)
{
    [PSCustomObject] @{
    'Description' = 'Finds inactive eBO instances for removal'
    '-h|--help' = 'display available options'
    '-s|--site' = 'specify a site number'
    '--remove|--delete' = 'enable prompt for removal of found or selected sites'
    #'--count' = 'get the number of completed sites'
    } | Format-list;exit
}

#--Get list of inactive sites that had eBO
if ($m_SID)
    {
        $INACTIVEEBO = Invoke-MySQL --site=000 --query="select * from sitetab where siteid = $M_SID and status = 'inactive' and ebo_server like 'cognos%' or siteid = $M_SID and status = 'inactive' and ebo_server like 'vmhost%' order by ebo_server,siteid;"
    }
        else
            {
                $INACTIVEEBO = Invoke-MySQL --site=000 --query="select * from sitetab where status = 'inactive' and ebo_server like 'cognos%' or status = 'inactive' and ebo_server like 'vmhost%' order by ebo_server,siteid;"
            }

ForEach ($SID1 in $INACTIVEEBO)
    {
        $SID = $SID1.siteid
        $EBO = $SID1.ebo_server   
        $EXISTS = plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBO "find /eBO -maxdepth 1 -name '*site$SID*'"
        #if ($EXISTS -like '*No such file*') {$EXIST = $false} #else {$EXISTS = $true}
        If ($EXISTS)
            {
                Write-host -NoNewline "Site$SID on $EBO`: "
                Write-host -NoNewline -ForegroundColor Red "[FOUND]"
                Write-Host $EXISTS
                if ($REMOVE)
                    {
                        $EXISTS
                        #--Confirmation from user
                        if (!$PROCEED)
                            {
                                Write-host "Remove site$SID eBO?"
                                Write-Host -NoNewline "Enter 'PROCEED' to continue: "
                                $RESPONSE = read-host
                                if ($RESPONSE -cne 'PROCEED') 
                                    {
                                        $break = $TRUE
                                    }
                            }
                                else
                                    {
                                        Write-host "PROCEED specified. Starting deletion..."
                                    }
                        if ($break -eq $TRUE)
                            {
                                break
                            }
                        ebomgr.ps1 --site=$SID --stop
                        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBO "kill -9 `$(ps ax|grep site$SID|awk '{print $1}')"
                        Write-Host -NoNewline "Removing eBO folder for site$SID..."
                        plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBO "find /eBO -maxdepth 1 -name '*site$SID*' -exec rm -rf {} \;"
                        if (-not(plink.exe -i \scripts\sources\ts01_privkey.ppk root@$EBO "find /eBO -maxdepth 1 -name '*site$SID*'"))
                            {
                                Write-Host -ForegroundColor Green '[OK]'
                            }
                                else
                                    {
                                        Write-Host -ForegroundColor Red '[FAIL]'
                                    }
                                            }
            }
                else
                    {
                        #Write-host -NoNewline "Site$SID on $EBO`: "
                        #Write-Host -ForegroundColor Green "[Deleted]"
                    }        
        }