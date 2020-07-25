#--Verify existence and file sizes of patch files for a specified site on their application servers

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1

#--Loop through the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '-s' -or $L -eq '--site'){$m_SID = $R}
        if ($L -eq '-p' -or $L -eq '--patch'){$PATCH = $R}
        if ($ARG -eq '-a') {$A = $TRUE}
        if ($ARG -eq '-b') {$B = $TRUE}
        if ($ARG -eq '--showmatching') {$SHOWMATCHING = $TRUE} else {$SHOWMATCHING = $FALSE}
        if ($ARG -eq '-h' -or $ARG -eq '--help'){$HELP = $TRUE}
    }

if($A -and $B)
    {
        Write-Host "cannot specify both tomcats"
        $HELP = $TRUE
    }
if (!$A -and !$B)
    {
        Write-Host "please specify one tomcat"
        $HELP = $TRUE
    }

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = "Verify patch and server files match"
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--patch|-p' = "Specify the patch number"
'-a|-b' = "Specify tomcat, -a|-b (not both)"
                }|Format-List; exit
            }


#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2,t.t1,t.t2,t.rdp_address,d.n1,d.n2,d.mysql_root from sitetab s inner join app_clusters a inner join ts_clusters t inner join db_clusters d where s.siteid = $m_SID and a.id=s.app_cluster_id and t.id=s.ts_cluster_id and d.cluster_name=s.db_cluster;"

#--Get the tomcat info
$APP1 = $SHOW.a1
$APP2 = $SHOW.a2
$APPARRAY = @()
$APPARRAY += $APP1,$APP2
if ($A)
    {
        $APP = $APP1
    }
if ($B)
    {
        $APP = $APP2
    }

$patchesfiles = @()
$ErrorActionPreference = 'SilentlyContinue'
foreach ($s in (gci "M:\scripts\patchcentral\patches\patch_$PATCH\Server" -recurse -Exclude 'ECWVoice' |where {$_.psiscontainer -eq $false} ).fullname)
    {
        $file_status = New-Object system.object
        $file = ($s.replace("M:\scripts\patchcentral\patches\patch_$PATCH\Server",''))
        $filename = $file.split('\')[-1]
        
        $test1 = (gci m:\scripts\patchcentral\patches\patch_$PATCH\server\$file -ErrorAction SilentlyContinue).Length
        
        $file_status| Add-Member -MemberType NoteProperty -Name site -Value $m_SID
        $test2 = (gci \\$APP\site$m_SID\tomcat7\$file).Length
        #$file_status| Add-Member -MemberType NoteProperty -Name FilePath -Value $file
        $file_status| Add-Member -MemberType NoteProperty -Name Filename -Value $filename
        $file_status| Add-Member -MemberType NoteProperty -Name SourceFile -Value $test1
        
        $file_status| Add-Member -MemberType NoteProperty -Name $APP -Value $test2
        if($test2 -ne $test1)
            {
                $file_status| Add-Member -MemberType NoteProperty -Name Match -Value $false
            }
                else
                    {
                        $file_status| Add-Member -MemberType NoteProperty -Name Match -Value $true
                    }
        <#foreach ($APP in $APPARRAY)
            {
                
            }#>
        
        $patchesfiles += $file_status
    }
$ErrorActionPreference = 'Continue'
$patchesfiles|where {$_.match -eq $SHOWMATCHING}