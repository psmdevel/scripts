#--Find inactive eBO instances on all eBO servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Get list of inactive sites that had eBO

$INACTIVEEBO = Invoke-MySQL --site=000 --query="select * from sitetab where status = 'inactive' and ebo_server like 'cognos%' or status = 'inactive' and ebo_server like 'vmhost%' order by ebo_server,siteid;"

foreach ($SID1 in $INACTIVEEBO)
    {
        $SID = $SID1.siteid
        $EBO = $SID1.ebo_server   
        $EXISTS = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store01 "ssh $EBO du -hs /eBO/*site$SID* 2>/dev/null"
        #if ($EXISTS -like '*No such file*') {$EXIST = $false} #else {$EXISTS = $true}
        If ($EXISTS)
            {
                Write-host -NoNewline "Site$SID on $EBO`: "
                Write-host -ForegroundColor Red "[FOUND]"
            }
                else
                    {
                        #Write-host -NoNewline "Site$SID on $EBO`: "
                        #Write-Host -ForegroundColor Green "[Deleted]"
                    }        
        #Write-Host "DEBUG: $SID $EXISTS"
                #Test-Path \\$EBO\admin\eBO\site$SID*|Out-Null
        <#Write-host -NoNewline "Inactive eBO for site$SID`:"
        if ($EXISTS -eq $true)
            {Write-host "[FOUND]" -ForegroundColor Red}
                else
                    {Write-host "[NO]" -ForegroundColor Green}#>




    }