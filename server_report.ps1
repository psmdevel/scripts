#Import-Module M:\scripts\invoke-mysql.psm1
Import-Module M:\scripts\sources\_functions.psm1 -Force

$INFO_ARRAY = @()
foreach ($SERVERNAME in Invoke-MySQL -site 000 -query "select * from components where os like 'w%'  and hostname not in ('dc01','ts15','lab03','patch01') order by hostname;")
    {
        
        $SERVER = $SERVERNAME.hostname
        $HOST_INFO = New-Object System.Object
        if ($SERVERNAME.os -eq 'w')
            {
                if ($SERVER -like 'ts*')
                    {
                        if ((Invoke-MySQL -site 000 -query "select site_root from ts_properties where name = '$SERVER';").site_root -like 'n*')
                            {
                                $DISKNAME = 'N'
                            }
                                else
                                    {
                                        $DISKNAME = 'M'
                                    }
                    }
                        else
                            {
                                if ($SERVER -like 'mgt*')
                                    {
                                        $DISKNAME = 'M'
                                    }
                                        else
                                            {
                                                $DISKNAME = 'C'
                                            }
                            }
                $OS = gwmi -computername $SERVER -Namespace "root\cimv2" win32_operatingsystem|select caption,name,FreePhysicalMemory,TotalVisibleMemorysize
                $OSVERSION = $OS.caption #name.split('|')[0]
                $FREERAM = [math]::round($OS.FreePhysicalMemory / 1MB)
                $RAM = [math]::round($os.TotalVisibleMemorysize /1MB)
                #$RAM = [math]::round((gwmi -computername $SERVER win32_computersystem).totalphysicalmemory/1GB)
                $CORES = (gwmi -computername $SERVER win32_processor|measure-object -property numberofcores -sum).sum
                $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $SERVER -Filter "DeviceID='$DISKNAME`:'" |Select-Object size,freespace;
                $size = [math]::round($disk.size / 1GB)
                $space = [math]::round($disk.freespace / 1GB)
            }
        
        if ($SERVERNAME.os -eq 'l')
            {
                $RELEASE_FILE = (plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 ls -1 /etc|egrep 'os|redh'|grep release|head -1").tostring()
                $OSVERSION = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 head -1 /etc/$RELEASE_FILE"
                $CORES = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 'grep -c ^processor /proc/cpuinfo'"
                $RAM = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 free -g|grep Mem|sed 's/  */ /g'|cut -d' ' -f2"
                $FREERAM = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 free -g|grep Mem|sed 's/  */ /g'|cut -d' ' -f3"
                $FSLIST = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh $SERVER  ConnectTimeout=2 df -Pm|egrep -v 'rootfs|tmp|mnt|boot|Mounted'|sed 's/  */ /g'|cut -d' ' -f2-7"
                $
            }
        $HOST_INFO | Add-Member -Type NoteProperty -Name Name -Value $SERVER
        $HOST_INFO | Add-Member -Type NoteProperty -Name Version -Value $OSVERSION
        $HOST_INFO | Add-Member -Type NoteProperty -Name Cores -Value $CORES
        $HOST_INFO | Add-Member -Type NoteProperty -Name RAM -Value $RAM
        $HOST_INFO | Add-Member -Type NoteProperty -Name FreeRAM -Value $FREERAM
        $HOST_INFO | Add-Member -Type NoteProperty -Name DiskSize -Value $size
        $HOST_INFO | Add-Member -Type NoteProperty -Name FreeDisk -Value $space
        $INFO_ARRAY += $HOST_INFO
        #$HOST_INFO
    }
    $INFO_ARRAY
    #Get-WmiObject -ComputerName $SERVER -class "Win32_PhysicalMemoryArray"