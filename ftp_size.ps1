#--Get FTP sizes for sites matching certain criteria

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = "$R"}
        if ($L -eq '--description' -or $L -eq '--desc' -or $L -eq '-d' ){$DESC = "$R"}
        if ($ARG -eq '--help' -or $ARG -eq '-h'){$HELP = $TRUE}

    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Get FTP sizes for sites matching a keyword. ex. 'namm'"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--description|-d' = "Specify the keyword to search for"
                }|Format-List; exit
            }

#--Get the site information from ControlData
if (!$m_SID)
    {
        $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where keywords like '%$DESC%' and status = 'active' order by siteid;"
    }
        else
            {
                $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $m_SID and status = 'active';"
            }

#--Loop through the sites and create a report of the FTP size for each site
foreach ($SITE in $SHOW)
    {
        $SID = $SITE.siteid
        $KEYWORDS = $SITE.keywords
        #write-host "DEBUG SiteID: $SID"
        #write-host "DEBUG Keywords: $KEYWORDS"
        #--find the FTP directory
        $FTPSITE = plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09a "/scripts/ffs -s=$SID"
        #write-host "DEBUG FTPSITE: $FTPSITE"
        $FTPSIZE = (plink.exe -i \scripts\sources\ts01_privkey.ppk root@store09a "du -hs $FTPSITE/mobiledoc").split('/')[0]
        #$FTPSIZE = $FTPSIZE.split('/')[0]
        Write-Output "site$SID, $KEYWORDS, $FTPSIZE"
    }
