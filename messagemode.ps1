#--Messagemode. Runs AutoUpgrade_Dev.exe for specified site from its APU server


#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$m_SID = $R}
        if ($L -eq '--nolog') {$NOLOG = 'True'}
        if ($L -eq '--all') {$APUALL = 'True'}
        if ($L -eq '--config') {$Update_Config = $TRUE}
        if ($L -eq '--first') {$FIRST = $R}
        if ($L -eq '--last') {$LAST = $R}
    }

    
#--Test and confirm variables
If (!$m_SID -and !$APUALL) {write-output "No sites specified. Please use --site= or --all"; exit}
if ($APUALL) {$NOLOG = 'True'}

<#--Get the site information from ControlData
if ($m_SID)
    {$SHOW = Invoke-MySQL -site 000 -query "select * from sitetab where siteid = $m_SID;"}#>

#--Set the first and last site number to run
if ($APUALL)
    {
        
        if (!$FIRST)
            {
                $first1 = Invoke-MySQL -Site 000 -Query "select siteid from sitetab where status like 'a%' and siteid > 001 order by siteid;"
                $FIRST = $first1[0].siteid
            }
        if (!$LAST)
            {
                $last1 = Invoke-MySQL -Site 000 -Query "select siteid from sitetab where status like 'a%' and siteid < 999 order by siteid desc;"
                $LAST = $last1[0].siteid
            }
        $SHOWSID = (invoke-mysql -Site 000 -Query "select siteid from sitetab where status like 'a%' and siteid >= $FIRST and siteid <= $LAST order by siteid;").siteid
        $SHOWSID = $SHOWSID |where {$_ -ge $FIRST -and $_ -le $LAST}|sort
        #$SHOWSID = $SHOWSID1.siteid
    }

#--Define the lower and upper range of site numbers to run against
if ($m_SID)
    {$SITEARRAY = @()
     $SITEARRAY += $m_SID}
     else
        {
            $SITEARRAY = $SHOWSID#|ForEach-Object {$_.ToString("000")}       
        }

if ($SITEARRAY.count -gt 1)
    {
        [PSCustomObject] @{
            sites = $SITEARRAY.count
            first = $SITEARRAY[0]
            last = $SITEARRAY[-1]
                          }|Format-List
    }
<#--Find the APU server, if siteid is specified
if ($m_SID)
    {
        $APU = $SHOW.apu_id
        $APUAGENT = "ecwapuagent" + $APU
        $APU06 = gwmi -ComputerName apu06 -query "select * from win32_service where name='$APUAGENT'"
        if ($APU06 -and $APU06.status -eq 'Running') 
            {$APUSRV = 'apu06';$APUSERVICE = gwmi -ComputerName apu06 -query "select * from win32_service where name='$APUAGENT'"}
                else 
                    { if ($m_SID -gt 499) {$APUSRV = 'apu05';$APUSERVICE = gwmi -ComputerName apu05 -query "select * from win32_service where name='$APUAGENT'"}
                        else
                            {$APUSRV = 'apu04';$APUSERVICE = gwmi -ComputerName apu04 -query "select * from win32_service where name='$APUAGENT'"}
                    }
    }#>
#Write-Host "DEBUG: $SITEARRAY"
foreach ($SID in $SITEARRAY)
    {
        #Write-Host "DEBUG: $SID"
        $SHOW = Show-Site --site=$SID --tool
        #$SHOW = Invoke-MySQL -site 000 -query "select * from sitetab where siteid = $SID;"
        if (!$SHOW -or $SHOW.status -like 'i*')
            {
                Write-Host "specified site is either inactive or does not exist";exit
            }
        $APU = $SHOW.apu_id
        $APUAGENT = "ecwapuagent" + $APU
        $APU06 = gwmi -ComputerName apu06 -query "select * from win32_service where name='$APUAGENT'"
        if ($APU06 -and $APU06.state -eq 'Running') 
            {$APUSRV = 'apu06';$APUSERVICE = gwmi -ComputerName apu06 -query "select * from win32_service where name='$APUAGENT'"}
                else 
                    { if ($SID -gt 499) {$APUSRV = 'apu05';$APUSERVICE = gwmi -ComputerName apu05 -query "select * from win32_service where name='$APUAGENT'"}
                        else
                            {$APUSRV = 'apu04';$APUSERVICE = gwmi -ComputerName apu04 -query "select * from win32_service where name='$APUAGENT'"}
                    }
        if ($APUSERVICE)
            {
                $REMOTE_PATH = ($APUSERVICE.pathname).split('\')[3]
                if ($Update_Config)
                    {
                        Write-Host "Opening AutoUpgrade_dev.exe.config..."
                        notepad \\$APUSRV\c$\sites\$SID\$REMOTE_PATH\AutoUpgrade_dev.exe.config|Wait-Process
                    }
                Write-Host -NoNewline "Running messagemode for site$SID on $APUSRV"
                Invoke-Command -ComputerName $APUSRV -ScriptBlock {messagemode.ps1 --site=$using:SID} <#-SessionOption (New-PSSessionOption -NoMachineProfile -SkipCACheck )#> |Wait-Process
                $TEST = Get-Content \\$APUSRV\c$\sites\$SID\$REMOTE_PATH\logs\eCW_AutoUpgrade.log
                if ($TEST[-1] -like '*done*')
                    {
                        Write-Host -ForegroundColor Green "[OK]"
                    }
                        else
                        {
                            Write-Host -ForegroundColor Red "[FAIL]"
                        }
        
                #Get-Process -ComputerName $APUSRV AutoUpgrade_Dev|Where-Object {$_.path -like "*$SID*"}|Wait-Process
                if (!$NOLOG)
                    {
                        notepad \\$APUSRV\c$\sites\$SID\$REMOTE_PATH\logs\eCW_AutoUpgrade.log
                    }
            }
    }