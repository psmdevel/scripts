#--Update planned downtime table for a practice

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--Process any arguments
foreach ($ARG in $ARGS)
    {
            $L,$R = $ARG -split '=',2
            if ($L -eq '--site' -or $L -eq '-s' ){$m_SID = $R}
            if ($L -eq '-h' -or $L -eq '--help') {$HELP = $TRUE}
            if ($L -eq '--type') {$TYPE = $R}
            if ($L -eq '--start') {$m_START_TIME = $R}
            if ($L -eq '--capsule' -or $L -eq '-c') {$CAPSULE = $R}
            if ($L -eq '--duration') {[int]$DUR = $R}
            if ($L -eq '--proceed' -or $L -eq '-y') {$PROCEED = 'True'}
            if ($L -eq '--list' -or $L -eq '-l') {$LIST = $TRUE}
            if ($L -eq '--date' -or $L -eq '-d') {$DATE = $R}
            if ($L -eq '--ticket') {[int]$TICKET = $R}
    }


if (!$HELP)
    {
    if ($LIST)
        {
            if (!$DATE)
                {
                    Write-Host "--date must be specified with --list"
                    $HELP = $TRUE
                }
        }
            else
                {
                    if (!$CAPSULE)
                        {
                            Write-Host "Capsule ID required"
                            $HELP = $TRUE
                        }
                    if (!$m_SID)
                        {
                            Write-Host "Site ID required"
                            $HELP = $TRUE
                        }
                    if (!$TYPE)
                        {
                            Write-Host "Type required"
                            $HELP = $TRUE
                        }
                    if (!$TICKET)
                        {
                            Write-Host "Ticket number required"
                            $HELP = $TRUE
                        }
                    if (!$DUR)
                        {
                            Write-Host "Duration required"
                            $HELP = $TRUE
                        }
                    if ($DUR -gt 24)
                        {
                            Write-Host "Duration should not be greater than 24 hours"
                            $HELP = $TRUE
                        }
                    $TYPES = @('patch','maint','upgrade')
                    if ($TYPES -notcontains $TYPE)
                        {
                            Write-Host "Type required"
                            $HELP = $TRUE
                        }
        }
    }

    

#--Help
if ($HELP) {
[PSCustomObject] @{
'Description' = 'Updates planned_downtime table for a site with type, start_time, and duration'
'--help|-h' = "Display available options"
'--site|-s' = "Specify the site number"
'--capsule|-c' = "Specify the capsule_id, 000|001 (mycharts or cenevia)"
'--start' = "Specify start_time of downtime. example: 14:30 for 2:30pm, or `'2020-01-01 15:45`' for January 1st, 2020 at 3:45pm. If left blank, (now) is assumed."
'--duration' = 'Specify duration of downtime, max 24 hours'
'--type' = 'Specify type of work, patch|maint|upgrade'
'--ticket' = 'Specify numeric CW ticket number'
'--list|-l' = 'Show list of downtime entries for specified site'
'--date|-d' = 'Used with --list. Show list of downtime entries for specified date(yyyy-MM-dd)'
                }|Format-List; exit
            }

#--Check if there is already downtime planned for the same day
if ($LIST)
    {
        #Write-Host "DEBUG: Site$m_SID"
        #Write-Host "DEBUG: $DATE"
        #$EXISTING_DOWNTIME = 
        Invoke-MySQL -site 000 -update -query "select * from planned_downtime where siteid = $m_SID and event_start like '$DATE%';"|ft
        exit
    }

#--Define the start of the downtime
if ($m_START_TIME)
    {
        $m_START = (get-date -Format "yyyy-MM-dd HH:mm:ss" $m_START_TIME)
        if(!$m_START)
            {
                Write-Host "invalid start time entered. exiting";exit
            }
    }
        else
            {
                $m_START = (get-date -Format "yyyy-MM-dd HH:mm:ss")
            }

#--Define the end of the downtime
$END_TIME = (get-date $m_START).addhours($DUR).tostring("yyyy-MM-dd HH:mm:ss")


#--Define the resource
$RESOURCE = $env:USERNAME 

[PSCustomObject] @{
    capsule = $CAPSULE
    site = $m_SID
    start = $m_START
    end = $END_TIME
    duration = $DUR
    type = $TYPE
    ticket= $TICKET
                }|Format-List

#--Confirmation from user
if (!$PROCEED)
    {
        Write-host -NoNewline "Enter 'PROCEED' to schedule downtme: "
        $RESPONSE = Read-Host
        if ($RESPONSE -cne 'PROCEED') {exit}
    }
        else
            {Write-host "PROCEED specified. Scheduling downtime..."}
            
#--Schedule the downtime!
Invoke-MySQL -site 000 -update -query "insert into planned_downtime (capsule_id,siteid,event_start,event_end,event_type,resource,ticket_no) values ('$CAPSULE','$m_SID','$m_START','$END_TIME','$TYPE','$RESOURCE','$TICKET');"
