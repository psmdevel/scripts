#--populate ebo_server entries in the sitetab database

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force
Import-Module M:\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '--force' -or $L -eq '-f' ){$FORCE = 'True'}
            if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Scan eBO servers for a site install and update control_data if found"
'--help|-h' = "Display available options"
'--site|-s' = "Specify a site number"
                }|Format-List; exit
            }

#--Get the list of sites that have no entry for an ebo_server
if ($m_SID)
    {$SITEARRAY = Show-Site --site=$m_SID --tool

    #--Check to see the specified site already lists an ebo_server
    $HASEBO = $SITEARRAY.ebo_server
    if ($HASEBO -like 'vmhost*' -or $HASEBO -like 'cognos*' -and !$FORCE)
        {Write-Host "~: ebo_server exists on $HASEBO. Exiting.";exit}
     #$SITEARRAY += $m_SID
     <#Debugging
     Write-host "DEBUG: Site = $m_SID"
     Write-host "DEBUG: ARRAY-SID = $SITEARRAY.siteid"#>
     }
        else
            {
                $SITEARRAY = Invoke-MySQL -Site 000 -Query "select * from sitetab where status like 'a%' and siteid > 001 and ebo_server not like 'cognos%' and ebo_server not like 'vmhost%' order by siteid;"
            }
$SIDARRAY = @()
$COUNT = $SITEARRAY.siteid.Count

#--Report the number of sites to be scanned for eBO
if ($COUNT -gt 1)
    {Write-Host "~: Scanning $COUNT sites..."}
        else
            {Write-Host "~: Scanning $COUNT site..."}

#--Loop through the sites, updating the ebo_server entry if an eBO Server is found
foreach ($SID1 in $SITEARRAY)
    {$SID = $SID1.siteid
         <#Debugging
          Write-host "DEBUG: Inside Loop, Site = $SID" #>
     
     $FINDEBO = Connect-Ssh -ComputerName store01 -ScriptBlock "/scripts/find_ebo_site --site=$SID"
     if ($FINDEBO[1] -like '*found.')
            {$EBO = $FINDEBO[1].split(':')[0]
             Invoke-MySQL -Site 000 -Query "update sitetab set ebo_server = '$EBO' where siteid = $SID limit 1;"
             $EBOQUERY = Invoke-MySQL -Site 000 -Query "select * from sitetab where siteid = $SID;"
             $EBOUPDATE = $EBOQUERY.ebo_server
             write-host "~: site$SID eBO Server = $EBOUPDATE"
             $SIDARRAY += $SID 
            }
            else
                {
                    write-host "~: site$SID eBO Server = Not Found"
                }
    }
$TOTAL = $SIDARRAY.count
write-host "

Total sites needing sitetab ebo_server update: $TOTAL"