#--Compare Itemkeys

$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 #-Force
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force
Import-Module SimplySql

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site1' -or $L -eq '-s1') {$SID1 = $R}
        if ($L -eq '--site2' -or $L -eq '-s2') {$SID2 = $R}
        if ($L -eq '--help' -or $L -eq '-h') {$HELP = $TRUE}

    }

#--Display available options
if ($HELP)
{
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s1|--site1' = 'specify source site ID for comparison'
    '-s2|--site2' = 'specify other site ID'

    } | Format-list;exit
}

#--Connect to control DB
$AUTH = get-Auth.ps1
Open-MySqlConnection -Server dbclust11 -Credential $Auth -port 5000 -Database control_data

#--Query control DB for both sites
$SHOW = Invoke-SqlQuery -Query "select s.*,d.n1,d.n2,d.mysql_root from sitetab s inner join db_clusters d where siteid in ('$SID1','$SID2') and d.cluster_name=s.db_cluster and s.status like 'a%';"
Close-SqlConnection

#--Make sure you both sites are active
if ($SHOW.count -ne 2)
    {
        write-host "One or both selected sites do not exist or are inactive. Exiting"
        exit
    }

if ($SHOW.status -like 'i*'|where {$SHOW.siteid -eq $SID1})
    {
        Write-Host "Site$SID1 selected, but it is inactive. Exiting"
        exit
    }
if ($SHOW.status -like 'i*'|where {$SHOW.siteid -eq $SID2})
    {
        Write-Host "Site$SID2 selected, but it is inactive. Exiting"
        exit
    }
    
#--Get the database info, $SID1
$SHOWSID1 = $SHOW|where {$_.siteid -eq $SID1}
$DBCLUST1 = $SHOWSID1.db_cluster
$DBUSER1 = "site" + $SID1 + "_DbUser"
$DBPWD1 = $SHOWSID1.dbuser_pwd|Convertto-SecureString -AsPlainText -Force
$Auth_SID1 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DBUSER1, $DBPWD1

#--Get the database info, $SID1
$SHOWSID2 = $SHOW|where {$_.siteid -eq $SID2}
$DBCLUST2 = $SHOWSID2.db_cluster
$DBUSER2 = "site" + $SID2 + "_DbUser"
$DBPWD2 = $SHOWSID2.dbuser_pwd|Convertto-SecureString -AsPlainText -Force
$Auth_SID2 = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $DBUSER2, $DBPWD2

#--Get the itemkey information for $SID1
Open-MySqlConnection -Server $DBCLUST1 -Credential $Auth_SID1 -port 5$SID1 -Database mobiledoc_$SID1
$ITEMKEYS1 = Invoke-SqlQuery -Query "select * from itemkeys order by name;"
Close-SqlConnection

#--Get the itemkey information for $SID2
Open-MySqlConnection -Server $DBCLUST2 -Credential $Auth_SID2 -port 5$SID2 -Database mobiledoc_$SID2
$ITEMKEYS2 = Invoke-SqlQuery -Query "select * from itemkeys order by name;"
Close-SqlConnection

#--Compare itemkeys
#Compare-Object -ReferenceObject $ITEMKEYS1.name -DifferenceObject $ITEMKEYS2.name

$ITEMKEYS = @()
foreach ($ITEM in $ITEMKEYS1)
    {
        if ($ITEMKEYS2.name -notcontains $ITEM.name)
            {
                $ITEMKEY = New-Object System.Object
                $ITEMKEY | Add-Member -Type NoteProperty -Name Name -Value $ITEM.name
                $ITEMKEY | Add-Member -Type NoteProperty -Name ItemID -Value $ITEM.itemID
                $ITEMKEY | Add-Member -Type NoteProperty -Name Value -Value $ITEM.value
                $ITEMKEY | Add-Member -Type NoteProperty -Name Discrepency -Value 'Missing'
                $ITEMKEYS += $ITEMKEY
                $ITEMKEY
            }
                else
                    {
                        $ITEM2 = $ITEMKEYS2|where {$_.name -eq $ITEM.name}
                        if ($ITEM2.itemid -ne $ITEM.itemid)
                            {
                                $ITEMKEY = New-Object System.Object
                                $ITEMKEY | Add-Member -Type NoteProperty -Name Name -Value $ITEM.name
                                $ITEMKEY | Add-Member -Type NoteProperty -Name ItemID -Value $ITEM.itemID
                                $ITEMKEY | Add-Member -Type NoteProperty -Name Value -Value $ITEM.value
                                $ITEMKEY | Add-Member -Type NoteProperty -Name Discrepency -Value 'ItemID'
                                $ITEMKEY | Add-Member -Type NoteProperty -Name CurrentID -Value $ITEM2.ItemID
                                $ITEMKEY | Add-Member -Type NoteProperty -Name CurrentValue -Value $ITEM2.Value
                                $ITEMKEYS += $ITEMKEY
                                $ITEMKEY
                            }
                    
                        else
                            {
                                if ($ITEM2.value -ne $ITEM.value)
                                    {
                                        $ITEMKEY = New-Object System.Object
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name Name -Value $ITEM.name
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name ItemID -Value $ITEM.itemID
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name Value -Value $ITEM.value
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name Discrepency -Value 'Value'
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name CurrentID -Value $ITEM2.ItemID
                                        $ITEMKEY | Add-Member -Type NoteProperty -Name CurrentValue -Value $ITEM2.Value
                                        $ITEMKEYS += $ITEMKEY
                                        $ITEMKEY
                                    }
                            }
                    }
        #$ITEMKEYS += $ITEMKEY
        #$ITEMKEY
    }

$ITEMKEYS.count