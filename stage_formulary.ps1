<#--Stage Formulary Updates
    
    Specify the patch number for a Medispan or Multum update to push it to each database server prior to running the patch
#>

#--Get the local drive letter
$DRIVE = (Get-Location).Drive.Root

#--Import the Invoke-Mysql module to query for database server names
import-module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Loop through the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '-p' -or $L -eq '--patch'){$PATCH = $R}
        if ($L -eq '--delete'){$DELETE = '--delete'}
        if ($L -eq '--help' -or $L -eq '-h'){$HELP = 'True'}
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'--help or -h' = "Display this message"
'--patch= or -p=' = "Specify the site number"
'--delete' = "remove old patch data from servers"
                }|Format-List; exit
            }

#--Get the local drive letter
$DRIVE = (Get-Location).Drive.Root

#--Import the Invoke-Mysql module to query for database server names
import-module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Get the list of database servers
$HA_ARRAY = invoke-mysql --site=000 --query="select n1,n2 from db_clusters where n1 not like '%11%' and n1 not like '%18%';"

#--Get the directories and Formulary patch type
$PATCHDIR = "$DRIVE`scripts\PatchCentral\patches\patch_$PATCH\tool\runtime\mysql\data\"
$REMOTEDIR = "/scripts/sources/med_patches"
$FRMY = Get-ChildItem -Path $PATCHDIR
if ($FRMY.Name -eq 'medispan'){$PATCHTYPE = 'medispan'}
if ($FRMY.Name -eq 'multum'){$PATCHTYPE = 'multum'}
if (!$PATCHTYPE){Write-host "~: Patch is not a Medispan or Multum patch, or does not exist. Exiting"; exit}
$PATCHFILE = $PATCHTYPE + "_" + $PATCH + ".sql"
#Test-Path "$PATCHDIR$PATCHFILE"
#echo "$PATCHDIR$PATCHFILE";exit
#--Copy files to store01:/scripts/sources
if (!$DELETE)
    {
        if (-not (test-path \\store01\admin\scripts\sources\med_patches\$PATCHFILE))
            {
                Write-Output "~: Copying $PATCHFILE from '$PATCHDIR' to //store01/admin$REMOTEDIR/"
                #robocopy /NFL /NDL /NJH /NJS /nc /ns 
                pscp -i $DRIVE\scripts\sources\ts01_privkey.ppk "$PATCHDIR$PATCHFILE" root@store01:/scripts/sources/med_patches/
            }
    }

#--Get filesize of sql file
$SQL1 = (plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 "cd /scripts/sources/med_patches/;ls -l $PATCHFILE|grep -Eo '[0-9]{1,10}'").split(' ')[-5]

#--Copy files to each database server
if (!$DELETE)
    {
        foreach ($HA in $ha_array.n1 + $ha_array.n2|select -Unique|sort) 
            {
                #--Make sure the med_patches folder exists on the database server under /scripts/sources
                $MEDPATCHFOLDERTEST = plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "file $REMOTEDIR"
                if ($MEDPATCHFOLDERTEST -notlike '*directory')
                    {
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/;rm -f med_patches"|Out-Null
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/;mkdir med_patches"|Out-Null
                    }
                #--Check if the patch file exists on the database server and copy it in if it does not exist
                $MEDPATCHFILETEST = plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/med_patches/;file $PATCHFILE"
                if ($MEDPATCHFILETEST -like '*error*' -or $MEDPATCHFILETEST -like '*cannot*')
                    {
                        $COPY = $TRUE
                        Write-Host -NoNewline "~: Copying SQL file from store01 to $HA`:$REMOTEDIR"
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 "scp $REMOTEDIR/$PATCHFILE $HA`:$REMOTEDIR/"|Out-Null
                    }
                #--Make sure the filesize matches the source file on store01
                $SQL2 = (plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/med_patches/;ls -l $PATCHFILE|grep -Eo '[0-9]{1,10}'").split(' ')[-5]
                #$STORE01SIZE = $SQL1.split(' ')[-5]
                #$HASIZE = $SQL2.split(' ')[-5]
                #$SQL1 -eq $SQL2
                #Write-Host "DEBUG: $SQL1"
                #Write-Host "DEBUG: $SQL2"
                if ($SQL1 -ne $SQL2)
                    {
                        $COPY = $TRUE
                        Write-Host -NoNewline "~: Updating SQL file from store01 to $HA`:$REMOTEDIR"
                        plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 "scp $REMOTEDIR/$PATCHFILE $HA`:$REMOTEDIR/"|Out-Null
                    }
                if ($COPY)
                    {
                        $SQL3 = (plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/med_patches/;ls -l $PATCHFILE|grep -Eo '[0-9]{1,10}'").split(' ')[-5]

                        if ($SQL1 -eq $SQL3)
                            {
                                Write-host -ForegroundColor Green "[Done]"
                            }
                                else
                                    {
                                        Write-host -ForegroundColor Red "[FAIL]"
                                    }
                    }    
                        else
                            {
                                Write-Host "$HA`: $PATCHFILE already exists"
                            }          
                      
            }
    }

    #--Remove files on each database server
if ($DELETE)
    {
        foreach ($HA in $ha_array.n1 + $ha_array.n2|select -Unique|sort) 
            {
                Write-Host -NoNewline "~: Removing $PATCHTYPE`_$PATCH.sql on $HA`:$REMOTEDIR..."
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@$HA "cd /scripts/sources/med_patches;rm -f $PATCHFILE"#|Out-Null
                Write-host "Done"        
            }
                Write-Host -NoNewline "~: Removing $PATCHTYPE`_$PATCH on store01:$REMOTEDIR..."
                plink -i $DRIVE\scripts\sources\ts01_privkey.ppk root@store01 "cd /scripts/sources/med_patches;rm -f $PATCHFILE"#|Out-Null
                Write-host "Done"
    }