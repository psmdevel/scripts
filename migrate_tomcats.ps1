#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Get the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--host'){$LABHOST = $R}
        if ($ARG -eq '-y'){$PROCEED = '-y'}
        if ($ARG -eq '--stage'){$STAGE = 'True'}
        if ($L -eq '--version' -or $L -eq '-ver'){$TOMCATVER = $R}
    }

#--Confirm the argument
if (!$LABHOST){Write-Output 'Please specify a source interface server using --host='; exit}

#--Test to make sure source interface server is actually an interface server
if (test-path -Path \\$LABHOST\c$\alley -IsValid){Write-Output 'You chose an interface server. YAY!'} else {Write-Output 'Please choose an actual interface server, or verify connectivity to interface server'; exit}

#--Select the active tomcats to migrate
$SERVICEARRAY = gwmi -ComputerName $LABHOST win32_service|?{$_.displayName -like 'apache tomcat*' -and $_.startmode -eq 'auto'}

#--Select and set tomcat version
if (!$TOMCATVER)
    {$TOMCATDIR = 'tomcat6'; $TOMCATVER = '6'} 
        else{
                if ($TOMCATVER -is [int]){$TOMCATDIR = "tomcat$TOMCATVER"} else {Write-Output 'Specify Tomcat version as an Integer';exit }
    }


foreach ($SID1 in $SERVICEARRAY)
    {
        $SID = $SID1.name
#--Get the application tomcat hostname
        $SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
        $APPCID = $SHOW.app_cluster_id[0]
        $APPID = Invoke-MySQL -s=000 --query="select * from app_clusters where id = $APPCID;"
        $APP = $APPID.a1

#--Copy the local $TOMCATDIR template to c:\alley\site"$SID"\

        Write-Host -NoNewline "Copying local Tomcat files..."
        robocopy /COPYALL /E /NFL /NDL /NJH /NJS /nc /ns /xo "c:\alley\_template (Do Not Delete)\$TOMCATDIR" c:\alley\site$SID\$TOMCATDIR\
        Write-host "Done"

#--Copy the mobiledoc folder from the application tomcat

        Write-Host -NoNewline "Copying Application Tomcat files..."
        robocopy /E /NFL /NDL /NJH /NJS /nc /ns /xo /PURGE \\$APP\site$SID\$TOMCATDIR\webapps\mobiledoc c:\alley\site$SID\$TOMCATDIR\webapps\mobiledoc\
        Write-host "Done"
    }

<#
#--Zip the mobiledoc directory from source interface server to new interface server
foreach ($SID1 in $SERVICEARRAY)
    {
        $SID = $SID1.name
        Write-host -NoNewline "Zipping site$SID..."
        & 'C:\Program Files\7-Zip\7z.exe' u -tzip c:\alley\site$SID\tomcat6\webapps\mobiledoc.zip  \\$LABHOST\c$\alley\site$SID\tomcat6\webapps\mobiledoc
        Write-host "Done."
    }

#--Unzip the mobiledoc.zip files for each tomcat
foreach ($SID1 in $SERVICEARRAY)
    {
        $SID = $SID1.name
        Write-host -NoNewline "Unzipping site$SID..."
        & 'C:\Program Files\7-Zip\7z.exe' x c:\alley\site$SID\tomcat6\webapps\mobiledoc.zip  -oc:\alley\site$SID\tomcat6\webapps\
        Write-Host "Done."
    }
#>

#--Install each tomcat
if (!$STAGE)
    {
      foreach ($SID1 in $SERVICEARRAY)
        {
            $SID = $SID1.name
            install_tomcat "-s=$SID --version=$TOMCATVER $PROCEED --staged --migrate"
        }
    }

#--Fix the memory allocation for each tomcat
if (!$STAGE)
    {
       foreach ($SID1 in $SERVICEARRAY)
        {
            $SID = $SID1.name
            import_memory "-s=$SID --host=$LABHOST $PROCEED"
        }
    }