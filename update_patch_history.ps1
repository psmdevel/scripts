#--Update last patch date and time for a server or component

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
	{
			$L,$R = $ARG -split '=',2
			if ($L -eq '--component' -or $L -eq '-c'){$COMP = $R}
			if ($L -eq '--help' -or $L -eq '-h') {$HELP = $TRUE}
			if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}
    }
	
if (!$COMP)
    {
        Write-Host "Component name required."
    }
	
#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Creates an entry in the patch_history table used for keeping track of the patch histories of components'
'--help|-h' = "Display available options"
'--component|-c' = "Specify the server or component name"
                }|Format-List; exit
            }
	
#--Define patch date and time
$PATCH_DATE = (get-date -Format "yyyy-MM-dd HH:mm:ss")
	
#--Define the resource
$RESOURCE = $env:USERNAME

[PSCustomObject] @{
    component = $COMP
    'patch time' = $PATCH_DATE
                }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to update patch history: "
        $RESPONSE = Read-Host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Updating patch history..."}
            

#--Update patch_history table
Invoke-MySQL -site 000 -update -query "insert into patch_history (component_name,patch_date,resource) values ('$COMP','$PATCH_DATE','$RESOURCE');"