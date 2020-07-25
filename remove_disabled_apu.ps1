$service_array = gwmi  win32_service|where{$_.displayname -like "eCW APU Agent*" -and $_.startmode -eq "disabled"}|select name, displayname, startmode, state, pathname



foreach ($service in $service_array){

$APU = $service.name
sc.exe delete $APU
<#$SID = $service.pathname.split("\")[2]

$EXISTS = Test-Path c:\sites\$SID

if ($EXISTS -eq 'True'){Remove-Item -Force -Recurse c:\sites\$SID}
#>
}