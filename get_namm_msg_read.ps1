Import-Module M:\scripts\sources\_functions.psm1 -Force

$NammMsgStatus = @()
foreach ($s in (Invoke-MySQL -Site 000 -Query "select siteid from sitetab where status like 'a%' and keywords like '%namm' order by siteid;").siteid)
    {
        $SiteMsgs = @()
        $show = Show-Site --site=$s --tool
        $msgs = Invoke-MySQL -Site $s -Query "select u.usertype as UserType,u.uname as UserName,u.ulname as LastName,u.ufname as FirstName,m.status as 'Read' from message m inner join users u where m.subject = 'an important message from namm' and msgto in (select uid from users where usertype in (1,2) and delflag = 0 and status = 0) and u.uid = m.msgto;"
        $notread = ($msgs|where {$_.read -eq 0}|Measure-Object).count
        $ReadMsgs = ($msgs|where {$_.read -eq 1}|Measure-Object).count
        $totalmsgs = $msgs.count
        $readpercentage = ($readmsgs) / ($totalmsgs)
        $readpercentage = ($readpercentage).tostring("P")
        $userid = 0
        foreach ($msg in $msgs)
            {
                $STATUS = New-Object system.object
                $SUMMARY = New-Object system.object
                if ($msg.usertype -eq 1)
                    {
                        $UserType = 'Provider'
                    }
                if ($msg.usertype -eq 2)
                    {
                        $UserType = 'Staff'
                    }
                $STATUS | Add-Member -Type NoteProperty -Name Siteid -Value $show.siteid
                $STATUS | Add-Member -Type NoteProperty -Name APU_ID -Value $show.apu_id
                $STATUS | Add-Member -Type NoteProperty -Name PracticeName -Value $show.keywords
                $STATUS | Add-Member -Type NoteProperty -Name LastName -Value $msg.LastName
                $STATUS | Add-Member -Type NoteProperty -Name FirstName -Value $msg.FirstName
                #$STATUS | Add-Member -Type NoteProperty -Name UserName -Value $msg.UserName
                $STATUS | Add-Member -Type NoteProperty -Name UserType -Value $UserType
                if ($msg.read -eq 1)
                    {
                        $STATUS | Add-Member -Type NoteProperty -Name Read -Value $True
                    }
                if ($msg.read -eq 0)
                    {
                        $STATUS | Add-Member -Type NoteProperty -Name Read -Value $False
                    }
                $userid ++
                $userpercentage = ($userid/$totalmsgs).ToString("P")
                $STATUS | Add-Member -Type NoteProperty -Name UserCountId -Value $userid
                $STATUS | Add-Member -Type NoteProperty -Name TotalMessages -Value $totalmsgs
                $STATUS | Add-Member -Type NoteProperty -Name ReadMessages -Value $ReadMsgs
                $STATUS | Add-Member -Type NoteProperty -Name UserPercent -Value $userpercentage
                $STATUS | Add-Member -Type NoteProperty -Name PercentRead -Value $readpercentage
                
                #$userpercentage = [math]::round($userpercentage,2)
                <#if ($userid -eq $msgs.count)
                    {
                        $STATUS | Add-Member -Type NoteProperty -Name TotalMessages -Value $totalmsgs
                        $STATUS | Add-Member -Type NoteProperty -Name ReadMessages -Value $msgs.count
                        $STATUS | Add-Member -Type NoteProperty -Name PercentRead -Value $readpercentage
                    }#>
                $SiteMsgs += $STATUS
                #$SUMMARY | Add-Member -Type NoteProperty -Name Siteid -Value $show.siteid
                #$SUMMARY | Add-Member -Type NoteProperty -Name APU_ID -Value $show.siteid
            }
        $NammMsgStatus += $SiteMsgs
        $SiteMsgs
    }

#$NammMsgStatus