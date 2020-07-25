#--Showdown

$SHOWDOWN = plink -i M:\scripts\sources\ts01_privkey.ppk root@store01 "ssh extrovert 'showdown'"|select-string 192
$DOWN_ARRAY = @()
#$SHOWDOWN = $SHOWDOWN.ToString()
#$SHOWDOWN = $SHOWDOWN.TrimStart('->')
foreach ($s in $SHOWDOWN)
    {
        $DOWNLIST = New-Object System.Object
        $SRV = ($s.ToString()).split(' ')[3]
        $IP = $SRV.split(':')[0]
        $HOSTNAME = (((nslookup $IP)[3]).split(' ')[4]).split('.')[0]
        $PORT = $SRV.split(':')[1]
        if ($PORT.length -eq 4 -and $PORT -ne '3389' -and $PORT -ne '7001')
            {
                $TYPE = $PORT.Substring(0,1)
                $SID = $PORT.Substring(1,3)
                if ($TYPE -eq '3')
                    {
                        $TMP = $HOSTNAME.substring(3,2)
                        $RESULT  = $TMP % 2
                        if ($RESULT -eq 0)
                            {
                                $TYPE = 'TomcatB'
                            }
                                else
                                    {
                                        if ($RESULT -eq 1)
                                            {
                                                $TYPE = 'TomcatA'
                                            }
                                    }
                    }
                        else
                            {
                                if ($TYPE -eq '9')
                                    {
                                        $TYPE = 'eBO'
                                    }
                                        else
                                            {
                                                if ($TYPE -eq '5')
                                                    {
                                                        $TYPE = 'MySQL'
                                                    }
                                            }
                            }
                                
            }
                else 
                    {
                        if ($PORT -eq '445')
                            {
                                $TYPE = 'SMB'
                            }
                        if ($PORT -eq '21')
                            {
                                $TYPE = 'FTP'
                            }
                        if ($PORT -eq '3389')
                            {
                                $TYPE = 'RDP'
                            }
                        if ($PORT -eq '7001')
                            {
                                $TYPE = 'EHX'
                            }
                    }
        if (!$SID)
            {
               $DOWNLIST | Add-Member -Type NoteProperty -Name Host -Value "$HOSTNAME"
               $DOWNLIST | Add-Member -Type NoteProperty -Name Type -Value "$TYPE"
               $DOWNLIST | Add-Member -Type NoteProperty -Name Port -Value "$PORT"
            }
                else
                    {
                        $DOWNLIST | Add-Member -Type NoteProperty -Name SiteID -Value "$SID"
                        $DOWNLIST | Add-Member -Type NoteProperty -Name Host -Value "$HOSTNAME"
                        $DOWNLIST | Add-Member -Type NoteProperty -Name Type -Value "$TYPE"
                        $DOWNLIST | Add-Member -Type NoteProperty -Name Port -Value "$PORT"
                    }
            #write-host "DEBUG: $SID,$HOSTNAME,$TYPE,$PORT"
            $DOWN_ARRAY += $DOWNLIST
    }
$DOWN_ARRAY = $DOWN_ARRAY|Sort-Object siteid,type
$DOWN_ARRAY
