#--principle author: eric robinson
#--contributors:
#--purpose: calculates uptime stats and generates a report from an uptimerobot log

#######################################################################
#
# init
#
#######################################################################

#--set strict mode
#Set-StrictMode -Version 2.0

#--clear the screen
clear

#--import the mysql control mopdule
$DRIVE = (Get-Location).Drive.Root
#Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force 
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

#--init vars
$m_boolDebug=$False
$boolAllSites=$False
[int]$intTotalDownMins=0
$colSitesProcessed=New-Object System.Collections.ArrayList
$colSitesSelected=New-Object System.Collections.ArrayList
$colSitesWithDownTime=New-Object System.Collections.ArrayList
$colCustomWindows=New-Object System.Collections.ArrayList
$strSourceLogFile="\scripts\sources\uptimerobot-all_monitors-logs.csv"
$strDefaultWindowStartHr="22"
$objDefaultWindowHrs=New-TimeSpan -Days 0 -Hours 6 -Minutes 0

#--// functions //

#--function IsNumeric
Function IsNumeric($Value) {
    return $Value -match "^[\d\.]+$"
}

#--function LogIt
Function LogIt($strMsg) {
    If ($strMsg -like "*debug:*") {
        If ( $m_boolDebug -eq $True ) {
            Write-Host $strMsg
        }
    }
    Else {
        Write-Host $strMsg
    }
}

#--function DisplayHelp
Function DisplayHelp {
    LogIt "usage: calculate_sla [options]"
    LogIt
    LogIt "options:"
    [PSCustomObject] @{
    '-h|--help' = 'display available options'
    '-s|--site' = 'run report for specified site id'
    '-a|--all' = 'run report for all sites'
    '-d|--date' = 'specify reporting month as YYYY-MM, defaults to this month'
    '-v|--verbose' = 'debug mode'
    } | Format-list
}

#--verify that the source log file exists
If ( -not (Test-Path $strSourceLogFile) ) {
    "err: the file $strSourceLogFile is missing."
     Exit
}

#######################################################################
#
# process cmd line args
#
#######################################################################

#--process command line options
[bool]$boolValidArg=$False
ForEach ($vArg in $ARGS) {

    [string]$strLeft,[string]$strRight = $vARG -split '=',2
    If ($strLEFT -eq '--site' -or $strLEFT -eq '-s') {
        [string]$strSID = $strRIGHT
        $boolValidArg=$True
    }
    If ($strLEFT -eq '--date' -or $strLEFT -eq '-d') {
        [string]$strTargetDate = $strRIGHT #--format: YYYY-MM
        $boolValidArg=$True
    }
    if ($strLEFT -eq '--all' -or $strLEFT -eq '-a') {
        [bool]$boolAllSites = $TRUE
        $boolValidArg=$True
    }
    if ($strLEFT -eq '--help' -or $strLEFT -eq '-h') {
        [bool]$boolHelp = $TRUE
        $boolValidArg=$True
    }
    if ($strLEFT -eq '--verbode' -or $strLEFT -eq '-v') {
        [bool]$m_boolDebug = $TRUE
        $boolValidArg=$True
    }
    If ( -not $boolValidArg) {
        LogIt "err: invalid argument '$vArg' specified"
        LogIt
        DisplayHelp
        Exit
    } 
    Else {
        $boolValidArg=$False
    }
}

#--display available options
If ($boolHelp)
{
    DisplayHelp
    Exit
}

#--// sanity checks //

#--must specify at least a sid or all sites
If (!$strSID -and !$boolAllSites) {
    LogIt "err: must specify one of: --site, --all"
    LogIt
    DisplayHelp
    Exit
}

#--if we are not doing all sites, sanity check the siteid 
If (!$boolAllSites) {


    #--see if the sitdID string is dot-delimited
    If ($strSID.Contains(".")) {
        #--split into capsule id and site id
        $strCapsuleId,$strSID = $strSID -split '\.',2
    }

    #--set the default capsule ID if necessary
    If (!$strCapsuleId) {
        $strCapsuleId="000"
    }

    #--pad with zeroes if necessary
    $strCapsuleId=$strCapsuleId.PadLeft(3,"0")
    $strSID=$strSID.PadLeft(3,"0")

    If ($(IsNumeric $strSID) -eq $FALSE -or $(IsNumeric $strCapsuleId) -eq $FALSE) {
        LogIt "err: siteid and capsule id must be numeric"
        LogIt
        DisplayHelp
        Exit
    }
    $strSID=$strSID.PadLeft(3,'0')
    $intSID=[int]$strSID
    $strTargetSite="$strCapsuleId.$strSID"
}


#--can't specify both a sid and all sites
If ($strSID -and $boolAllSites) {
    LogIt "err: incompatible terms specified; what do you want, site $strSID or all sites?"
    LogIt
    DisplayHelp
    Exit
}

#--check the date argument
If ($strTargetDate) {
    $strTargetYear,$strTargetMonth = $strTargetDate -split '-',2
}
Else {
    $strTargetYear=$(Get-Date -Format "yyyy")
    $strTargetMonth=$(Get-Date -Format "MM")
}
$intTargetYear=[int]$strTargetYear
$intTargetMonth=[int]$strTargetMonth
If ($intTargetYear -lt 2019 -or $intTargetYear -gt 9999 -or $intTargetMonth -lt 1 -or $intTargetMonth -gt 12) {
    LogIt "invalid date"
    Exit
} 

#--set sla minutes per month based on the number of days in the target month
$intDaysInMonth=[datetime]::DaysInMonth($intTargetYear,$intTargetMonth)
$intMinsInMonth=$($intDaysInMonth * 1020)

#--get days in the target month
$DaysInMonth=[datetime]::DaysInMonth($intTargetYear,$intTargetMonth)
        
#---begin output
LogIt "calculating sla for: $($strTargetYear)-$($strTargetMonth)"
If ($boolAllSites) {
    LogIt "target sites: (all)"
}
Else {
    LogIt "target site: $($strTargetSite)"
}

#######################################################################
#
# create the collection of active sites: $colActiveSites
#
#######################################################################

#--get active site list
LogIt "getting list of active Vegas SaaS sites"
$colActiveSites = Invoke-MySQL -Site 000 -Query "select siteid from sitetab where status='active' and siteid > '000' order by siteid;"


#######################################################################
#
# create custom maint window collection
#
#######################################################################

#--get maint window exceptions 
LogIt "getting customer-specific maintenance windows"
$colCustomWindowExceptions = Invoke-MySQL -Site 000 -Query "select * from maint_window_exceptions order by capsule_id, siteid;"

#--create maint window records for the exception sites and add them to the maint window collection"
LogIt "adding customer-specific maint windows to the collection" 

#--for each day of the month
For ($intDayCount=1;$intDayCount -le $intDaysInMonth;$intDayCount++) {
    
    #--for each site that has a custom window
    ForEach ($objMaintException In $colCustomWindowExceptions) {

        #--get capsule and site ids
        $strCapsule_Id=$objMaintException.Capsule_Id
        $strSiteId=$objMaintException.SiteID

        #--get custom window start hour and duration
        $intCustomWindowStartHour=$objMaintException.window_start_hour
        $intCustomWindowDurationHours=$objMaintException.window_duration_hours

        #--make the time entries
        [datetime]$dtCustomWindow_Start=[datetime]("$intTargetMonth/$intDayCount/$intTargetYear $($intCustomWindowStartHour):0:0")
        [datetime]$dtCustomWindow_End=$dtCustomWindow_Start.AddHours($intCustomWindowDurationHours)

        #--create an object
        $objTemp=New-Object System.Object
        $objTemp|Add-Member -MemberType NoteProperty -Name "capsule_id" -Value $strCapsule_Id
        $objTemp|Add-Member -MemberType NoteProperty -Name "siteid" -Value $strSiteId
        $objTemp|Add-Member -MemberType NoteProperty -Name "event_start" -Value $dtCustomWindow_Start
        $objTemp|Add-Member -MemberType NoteProperty -Name "event_end" -Value $dtCustomWindow_End

        #--add it to the master list
        $colCustomWindows.Add($objTemp) | Out-Null

        #"strCapsule_Id=$strCapsule_Id"
        #"strSiteId=$strSiteId"
        #"dtCustomWindow_Start=$dtCustomWindow_Start"
        #"dtCustomWindow_End=$dtCustomWindow_End"
    }
}

#ForEach ( $objMaintWindow In $colCustomWindows ) {
#    LogIt "debug: $($objMaintWindow.capsule_id), $($objMaintWindow.siteid), $($objMaintWindow.event_start), $($objMaintWindow.event_end)"
#}
#LogIt "debug: $($colCustomWindows.count) records" 
#exit


#######################################################################
#
# get planned downtime records
#
#######################################################################

	LogIt "getting planned downtime entries"
    LogIt "debug: select * from planned_downtime where event_start like '$strTargetYear-$strTargetMonth%' order by capsule_id,siteid,event_start,event_end;"
	$colPlannedDowntime = Invoke-MySQL -Site 000 -Query "select * from planned_downtime where event_start like '$strTargetYear-$strTargetMonth%' order by capsule_id,siteid,event_start,event_end;"
    LogIt "debug: colPlannedDowntime.count=$($colPlannedDowntime.count)"


#######################################################################
#
# start processing the robot logs
#
#######################################################################

LogIt ""
LogIt "-Downtime Events from UptimeRobot Logs-"

#--read the uptime log in CSV format 
$colRobotLogLines=$(Import-CSV $strSourceLogFile |Sort-Object -Property @{Expression = "Monitor"; Descending = $False}, @{Expression = "Date-Time"; Descending = $False}) 

#--loop through the lines in the uptime robot log
LogIt "debug: looping through robot log lines"
ForEach ($objRobotLogLine in $colRobotLogLines){

    #--reset total deducted minutes
    $intTotalDeductedMins=0

    #--extract the fields from the object
    $intEventMins=[int]$($objRobotLogLine."Duration (in mins.)")
    $strEventType = $($objRobotLogLine.Event)
    $strEventSite = $($objRobotLogLine.Monitor)
    $strEventReason = $($objRobotLogLine.Reason)
    $strEventUrl=$($objRobotLogLine."Monitor URL")    
    [datetime]$dtEventStartTime=$($objRobotLogLine."Date-Time")
    [datetime]$dtEventEndTime=$dtEventStartTime.AddMinutes($intEventMins)

    #--replace string "site" in the robot logs with "000." in the site IDs 
    $strEventSite=$strEventSite.Replace("site","000.")

    If ($strEventSite -eq "000.147") {
            write-host
    }

    #--format the site string for proper comparison to the database, since the robotlogs do not pad the zeroes properly
    $strCapsuleId,$strSID = $strEventSite -split '\.',2
    $strCapsuleId=$strCapsuleId.PadLeft(3,"0")
    $strSID=$strSID.PadLeft(3,"0")
    $strEventSite="$strCapsuleId.$strSID"

    #--search for the site in the colSitesProcessed collection (which starts empty and grows, 1 entry for each unique site encountered in the logs)
    [bool]$boolFound=$FALSE
    ForEach ($objItem in $colSitesProcessed) {
        $strSiteProcessed=$($objItem.Site)

        #--if the site from the robot logs event was found in the colSitesProcessed collection, no need to add it
        If ($strSiteProcessed -eq $strEventSite) {
            $boolFound=$TRUE
            Break
        }
    }
    
    #--if the site from the robot logs event was not found in the colSitesProcessed collection, add it 
    If (!$boolFound) {

        #--add it
        $objTemp=New-Object System.Object
        $objTemp|Add-Member -MemberType NoteProperty -Name "Site" -Value $strEventSite
        $colSitesProcessed.Add($objTemp) | Out-Null
        LogIt "debug: colSitesProcessed.count=$($colSitesProcessed.count)"
    }

    #--if we are not doing all sites, skip lines that don't match the specified sid
    If (!$boolAllSites) {
        If ($strEventSite -ne $strTargetSite) {
            Continue
        } 
    }

    #--search for the site in the colSitesSelected collection (which starts empty and grows, 1 entry for each site matched against our selection args, which would be a single site ID or all) 
    [bool]$boolFound=$FALSE
    ForEach ($objItem in $colSitesSelected) {
        $strSiteSelected=$($objItem.Site)

        #--if it was found, no need to add it
        If ($strSiteSelected -eq $strEventSite) {
            $boolFound=$TRUE
            Break
        }
    }
    
    #--if the processed site wasn't found in the colSitesSelected collection, add it 
    If (!$boolFound) {

        #--add it
        $objTemp=New-Object System.Object
        $objTemp|Add-Member -MemberType NoteProperty -Name "Site" -Value $strEventSite
        $colSitesSelected.Add($objTemp) | Out-Null
        LogIt "debug: colSitesSelected.count=$($colSitesSelected.count)"

    }

    #--skip any robot log events where the reason was not "keyword not found"
    If ($strEventReason -ne "Keyword Not Found") {
        Continue
    }
	
    #--skip robot log events where downtime minutes was 0 (don't know why uptimerobot does that). 
    If ($intEventMins -eq 0) {
        Continue
    }

    #--if the event neither started nor ended in the target month, skip it
    If ($dtEventStartTime.Month -ne $intTargetMonth -and $dtEventEndTime.Month -ne $intTargetMonth) {
        Continue
    }

    #--if the event started and ended in different months, modify the start or end date to reflect the target month
    If ($dtEventStartTime.Month -ne $dtEventEndTime.Month) {

        #--if event started the in the target month, modify the event end time to reflect the end of the target month
        If ($dtEventStartTime.Month -eq $strTargetMonth) {

            #--calculate the end of the month
            [int]$intEventMonth=$dtEventStartTime.Month
            $dtStartOfMonth = Get-Date -Year $intTargetYear -Month $intTargetMonth -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0
            $dtEventEndTime = ($dtStartOfMonth).AddMonths(1).AddTicks(-1)
            $intEventMins=[Math]::Round($(New-TimeSpan -Start $dtEventStartTime -End $dtEventEndTime).TotalMinutes)
        }
        Else {
            #--if the event started in the month prior to the target month, modify the event start time to reflect the start of the target month
            If ($dtEventEndTime.Month -eq $strTargetMonth) {
                $dtEventStartTime=[datetime]"$strTargetYear-$strTargetMonth-01" 
                $intEventMins=[Math]::Round($(New-TimeSpan -Start $dtEventStartTime -End $dtEventEndTime).TotalMinutes)
            }
        }
    
    }

    LogIt "debug: objRobotLogLine=$objRobotLogLine"
	LogIt "debug: intEventMins=$intEventMins"



#######################################################################
#
# deduct planned downtime minutes
#
#######################################################################


    LogIt "debug: loop through planned_downtime collection and subtract any appropriate minutes for this robot log entry"
    LogIt "debug: colPlannedDowntime.count=$($colPlannedDowntime.count)"
    $intTotalDeductedMins=0
    $intOldTotalDeductedMins=0
    ForEach($objPlannedSlot in $colPlannedDowntime) {

        #--take the capsule id and site id from the planned_downtime slot and make a site id string for comparing against the robotlog events
        $strA=$objPlannedSlot.Capsule_ID
        $strB=$objPlannedSlot.SiteID
        $strPlannedMaintSite="$strA.$strB"

        #--reset deducted minutes for this downtime slot
        $intPdDeductedMins=0

        #--if the planned_downtime slot contains a site that matches the robotlog event site...
        If ($strPlannedMaintSite -eq $strEventSite) {
            
            #--get the planned slots start and end times
            $dtPlannedStartTime=[datetime]$objPlannedSlot.Event_Start
            $dtPlannedEndTime=[datetime]$objPlannedSlot.Event_End

            #"strPlannedMaintSite=$strPlannedMaintSite"
            #"dtPlannedStartTime=$dtPlannedStartTime"
            #"dtPlannedEndTime=$dtPlannedEndTime"


            #--if the robotlog event ends before the planned maint starts, there are no minutes to deduct
            If ($dtEventEndTime -le $dtPlannedStartTime) {
                LogIt "debug: skipping deductions because event is over before the planned maint window entry starts" 
                LogIt "debug:      dtEventEndTime ($dtEventEndTime) < dtPlannedStartTime ($dtPlannedStartTime)"
                continue 
            }

            #--if the robotlog event starts after the planned maint window ends, we cannot deduct minutes
            If ($dtEventStartTime -ge $dtPlannedEndTime) { 
                LogIt "debug: skipping deductions because event starts after the planned maint window entry ends" 
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtPlannedEndTime ($dtPlannedEndTime)"
                continue 
            }

            #--if the robotlog event starts before the planned maint window starts and ends before the planned maint window ends, we deduct the delta minutes from the event
            If ($dtEventStartTime -le $dtPlannedStartTime -and $dtEventEndTime -lt $dtPlannedEndTime) {
                $intPdDeductedMins=$(New-TimeSpan -Start $dtPlannedStartTime -End $dtEventEndTime).TotalMinutes
                LogIt "debug: deducting $intPdDeductedMins mins because the last part of the event falls into the planned maint window entry" 
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) -le dtPlannedStartTime ($dtPlannedStartTime) -and dtEventEndTime ($dtEventEndTime) -lt dtPlannedEndTime ($dtPlannedEndTime)."
            }

            #--if the robotlog event starts after the planned maint window starts and ends after the planned maint window ends, we deduct the delta minutes from the event 
                If ($dtEventStartTime -ge $dtPlannedStartTime -and $dtEventEndTime -ge $dtPlannedEndTime) {
                $intPdDeductedMins=$(New-Timespan -Start $dtEventStartTime -End $dtPlannedEndTime).TotalMinutes
                LogIt "debug: deducting $intPdDeductedMins mins because first part of event falls into the planned maint window entry."
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtPlannedStartTime ($dtPlannedStartTime) -and dtEventEndTime ($dtEventEndTime)  >= dtPlannedEndTime ($dtPlannedEndTime)."
            }

            #--if the robotlog event starts before the planned maint window starts and ends after the planned maint window ends, we deduct the delta minutes from the event
            If ($dtEventStartTime -le $dtPlannedStartTime -and $dtEventEndTime -ge $dtPlannedEndTime) {
                $intPdDeductedMins=$(New-Timespan -Start $dtPlannedStartTime -End $dtPlannedEndTime).TotalMinutes
                LogIt "debug: deducting $intPdDeductedMins mins because the middle part of the event falls into the planned maint window entry"
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) <= dtPlannedStartTime ($dtPlannedStartTime) -and dtEventEndTime ($dtEventEndTime) >= dtPlannedEndTime ($dtPlannedEndTime)"
            }

            #--if the robotlog event starts after the planned maint window starts and ends before the main window ends, we deduct those minutes from the event
            If ($dtEventStartTime -ge $dtPlannedStartTime -and $dtEventEndTime -le $dtPlannedEndTime) {
                $intPdDeductedMins=$(New-TimeSpan -Start $dtEventStartTime -End $dtEventEndTime).TotalMinutes
                LogIt "debug: deducting $intPdDeductedMins mins because whole event falls into the planned maint window entry"
                LogIt "debug:     dtEventStartTime ($dtEventStartTime) >= dtPlannedStartTime ($dtPlannedStartTime) -and dtEventEndTime ($dtEventEndTime) <= dtPlannedEndTime ($dtPlannedEndTime)."
            }

            #--accumulate the deducted minutes
            $intTotalDeductedMins=$intTotalDeductedMins+$intPdDeductedMins

        }
    }
    If ( $intTotalDeductedMins -eq $intOldTotalDeductedMins ) {
        LogIt "debug: no minutes deducted for planned downtime"
    }

#######################################################################
#
# deduct custom maint window minutes
#
#######################################################################


    LogIt "debug: loop through custom  window collection and subtract any appropriate minutes for this robot log entry"
    LogIt "debug: colCustomWindows.count=$($colCustomWindows.count)"
    $intOldTotalDeductedMins=$intTotalDeductedMins
    $boolHasCustomWindow=$False
    ForEach($objCustomSlot in $colCustomWindows) {

        #--take the capsule id and site id from the Custom_downtime slot and make a site id string for comparing against the robotlog events
        $strA=$objCustomSlot.Capsule_ID
        $strB=$objCustomSlot.SiteID
        $strCustomSite="$strA.$strB"

        #--reset deducted minutes for this downtime slot
        $intCwDeductedMins=0

        #--if the Custom_downtime slot contains a site that matches the robotlog event site...
        If ($strCustomSite -eq $strEventSite) {

            #--this site has a custom maint window, so later we'll skip standard maint window processing
            $boolHasCustomWindow=$True
            
            #--get the Custom slots start and end times
            $dtCustomStartTime=[datetime]$objCustomSlot.Event_Start
            $dtCustomEndTime=[datetime]$objCustomSlot.Event_End


            #--if the robotlog event ends before the Custom Custom starts, there are no minutes to deduct
            If ($dtEventEndTime -le $dtCustomStartTime) {
                LogIt "debug: skipping deductions because event is over before the custom window" 
                LogIt "debug:      dtEventEndTime ($dtEventEndTime) < dtCustomStartTime ($dtCustomStartTime)"
                continue 
            }

            #--if the robotlog event starts after the Custom Custom window ends, we cannot deduct minutes
            If ($dtEventStartTime -ge $dtCustomEndTime) { 
                LogIt "debug: skipping deductions because event starts after the custom window" 
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtCustomEndTime ($dtCustomEndTime)"
                continue 
            }

            #--if the robotlog event starts before the custom window starts and ends before the custom window ends, we deduct the delta minutes from the event
            If ($dtEventStartTime -le $dtCustomStartTime -and $dtEventEndTime -lt $dtCustomEndTime) {
                $intCwDeductedMins=$(New-TimeSpan -Start $dtCustomStartTime -End $dtEventEndTime).TotalMinutes
                LogIt "debug: deducting $intCwDeductedMins mins because the last part of the event falls into the custom window" 
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) -le dtCustomStartTime ($dtCustomStartTime) -and dtEventEndTime ($dtEventEndTime) -lt dtCustomEndTime ($dtCustomEndTime)."
            }

            #--if the robotlog event starts after the custom window starts and ends after the main window ends, we deduct the delta minutes from the event 
                If ($dtEventStartTime -ge $dtCustomStartTime -and $dtEventEndTime -ge $dtCustomEndTime) {
                $intCwDeductedMins=$(New-Timespan -Start $dtEventStartTime -End $dtCustomEndTime).TotalMinutes
                LogIt "debug: deducting $intCwDeductedMins mins because first part of event falls into the custom window."
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtCustomStartTime ($dtCustomStartTime) -and dtEventEndTime ($dtEventEndTime)  >= dtCustomEndTime ($dtCustomEndTime)."
            }

            #--if the robotlog event starts before the custom window starts and ends after the custom window ends, we deduct the delta minutes from the event
            If ($dtEventStartTime -le $dtCustomStartTime -and $dtEventEndTime -ge $dtCustomEndTime) {
                $intCwDeductedMins=$(New-Timespan -Start $dtCustomStartTime -End $dtCustomEndTime).TotalMinutes
                LogIt "debug: deducting $intCwDeductedMins mins because the middle part of the event falls into the custom window"
                LogIt "debug:      dtEventStartTime ($dtEventStartTime) <= dtCustomStartTime ($dtCustomStartTime) -and dtEventEndTime ($dtEventEndTime) >= dtCustomEndTime ($dtCustomEndTime)"
            }

            #--if the robotlog event starts after the Custom Custom window starts and ends before the main window ends, we deduct those minutes from the event
            If ($dtEventStartTime -ge $dtCustomStartTime -and $dtEventEndTime -le $dtCustomEndTime) {
                $intCwDeductedMins=$(New-TimeSpan -Start $dtEventStartTime -End $dtEventEndTime).TotalMinutes
                LogIt "debug: deducting $intCwDeductedMins mins because whole event falls into the custom window"
                LogIt "debug:     dtEventStartTime ($dtEventStartTime) >= dtCustomStartTime ($dtCustomStartTime) -and dtEventEndTime ($dtEventEndTime) <= dtCustomEndTime ($dtCustomEndTime)."
            }

            #--accumulate the deducted minutes
            $intTotalDeductedMins=$intTotalDeductedMins+$intCwDeductedMins

        }
    }
    If ( $intTotalDeductedMins -eq $intOldTotalDeductedMins ) {
        LogIt "debug: no minutes deducted for custom windows"
    }
	
#######################################################################
#
# deduct minutes for the standard maint windows
#
#######################################################################

    LogIt "debug: deduct std maint window minutes for this robot log entry"
	
	$boolSkip=$False
    If ( $boolHasCustomWindow -eq $False ) {

        #--set the standard start and end times
        $strStartYear=$($dtEventStartTime.Year)
        $strStartMonth=$($dtEventStartTime.Month)
        $strStartDay=$($dtEventStartTime.Day)
        $dtStdMaintStartTime=[datetime]"$strStartYear-$strStartMonth-$strStartDay $($strDefaultWindowStartHr):00:00" 
        $dtStdMaintEndTime=$dtStdMaintStartTime + $objDefaultWindowHrs

        If ($dtEventEndTime -le $dtStdMaintStartTime) {
            LogIt "debug: skipping deductions because event is over before the standard maint window" 
            LogIt "debug:      dtEventEndTime ($dtEventEndTime) < dtStdMaintStartTime ($dtStdMaintStartTime)"
			$boolSkip=$True
        }

        #--if the robotlog event starts after the StdMaint maint window ends, we cannot deduct minutes
        If ($dtEventStartTime -ge $dtStdMaintEndTime) { 
            LogIt "debug: skipping deductions because event starts after the standard maint window" 
            LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtStdMaintEndTime ($dtStdMaintEndTime)"
			$boolSkip=$True
        }
		
		If ( $boolSkip -eq $False ) {

			#--if the robotlog event starts before the standard maint window starts and ends before the standard maint window ends, we deduct the delta minutes from the event
			If ($dtEventStartTime -le $dtStdMaintStartTime -and $dtEventEndTime -lt $dtStdMaintEndTime) {
				$intMwDeductedMins=$(New-TimeSpan -Start $dtStdMaintStartTime -End $dtEventEndTime).TotalMinutes
				LogIt "debug: deducting $intMwDeductedMins mins because the last part of the event falls into the maintenance window" 
				LogIt "debug:      dtEventStartTime ($dtEventStartTime) -le dtStdMaintStartTime ($dtStdMaintStartTime) -and dtEventEndTime ($dtEventEndTime) -lt dtStdMaintEndTime ($dtStdMaintEndTime)."
			}
	
			#--if the robotlog event starts after the standard maint window starts and ends after the standard maint window ends, we deduct the delta minutes from the event 
				If ($dtEventStartTime -ge $dtStdMaintStartTime -and $dtEventEndTime -ge $dtStdMaintEndTime) {
				$intMwDeductedMins=$(New-Timespan -Start $dtEventStartTime -End $dtStdMaintEndTime).TotalMinutes
				LogIt "debug: deducting $intMwDeductedMins mins because first part of event falls into the standard maint window."
				LogIt "debug:      dtEventStartTime ($dtEventStartTime) >= dtStdMaintStartTime ($dtStdMaintStartTime) -and dtEventEndTime ($dtEventEndTime)  >= dtStdMaintEndTime ($dtStdMaintEndTime)."
			}
	
			#--if the robotlog event starts before the standard maint window starts and ends after the standard maint window ends, we deduct the delta minutes from the event
			If ($dtEventStartTime -le $dtStdMaintStartTime -and $dtEventEndTime -ge $dtStdMaintEndTime) {
				$intMwDeductedMins=$(New-Timespan -Start $dtStdMaintStartTime -End $dtStdMaintEndTime).TotalMinutes
				LogIt "debug: deducting $intMwDeductedMins mins because the middle part of the event falls into the standard maint window"
				LogIt "debug:      dtEventStartTime ($dtEventStartTime) <= dtStdMaintStartTime ($dtStdMaintStartTime) -and dtEventEndTime ($dtEventEndTime) >= dtStdMaintEndTime ($dtStdMaintEndTime)"
			}
	
			#--if the robotlog event starts after the StdMaint maint window starts and ends before the standard maint window ends, we deduct those minutes from the event
			If ($dtEventStartTime -ge $dtStdMaintStartTime -and $dtEventEndTime -le $dtStdMaintEndTime) {
				$intMwDeductedMins=$(New-TimeSpan -Start $dtEventStartTime -End $dtEventEndTime).TotalMinutes
				LogIt "debug: deducting $intMwDeductedMins mins because whole event falls into the standard maint window"
				LogIt "debug:     dtEventStartTime ($dtEventStartTime) >= dtStdMaintStartTime ($dtStdMaintStartTime) -and dtEventEndTime ($dtEventEndTime) <= dtStdMaintEndTime ($dtStdMaintEndTime)."
			}
		}

    }
    Else {
        LogIt "debug: this site has a custom window; skipping standard window"
    }
	
	LogIt "debug: intEventMins after processing: $intEventMins"
	LogIt "debug: intTotalDeductedMins: $intTotalDeductedMins"

    #--accumulate the deducted minutes
    $intTotalDeductedMins=$intTotalDeductedMins+$intMwDeductedMins
    If ( $intTotalDeductedMins -eq $intOldTotalDeductedMins ) {
        LogIt "debug: no minutes deducted for standard maint windows"
    }

#######################################################################
#
# cleanup adjustment
#
#######################################################################


     #--it is possible that the down minutes could go negative if mins are deducted for StdMaint downtime and then deducted again for the std maintenance window. if that happens, make it 0. 
    If ($intTotalDeductedMins -gt $intEventMins) {
        $intAdjustedMins=0
    }
    Else {
        $intAdjustedMins=[Math]::Round($intEventMins-$intTotalDeductedMins)
    }


    LogIt "debug:      intEventMins=$intEventMins, intTotalDeductedMins=$intTotalDeductedMins, intAdjustedMins=$intAdjustedMins"

    #--display the down event
    LogIt "$strEventSite,$dtEventStartTime,$strEventType,$intAdjustedMins($intEventMins) mins" 
    LogIt "debug: -" 

    #--now search for the site object in the colSitesWithDownTime collection (which starts empty and grows, 1 entry for each site with unplanned downtime)
    [bool]$boolFound=$FALSE
    ForEach ($objItem in $colSitesWithDownTime) {

        #--get the down site name
        $strDownSite=$($objItem.Site)

        #--if it matches the event site name, update the (#adjusted?) downtime for that object
        If ($strDownSite -eq $strEventSite) {
            $intDownMins=$objItem.DownMins
            #$intDownMins += $intEventMins
            $intDownMins += $intAdjustedMins
            $objItem.DownMins=$intDownMins
            $boolFound=$TRUE
            Break
        }
    }
    
    #--if the event site was not found in the down sites collection, add it
    If (!$boolFound) {
        $objTemp=New-Object System.Object
        $objTemp|Add-Member -MemberType NoteProperty -Name "Site" -Value $strEventSite
        $objTemp|Add-Member -MemberType NoteProperty -Name "EventDateTime" -Value $dtEventStartTime
        #$objTemp|Add-Member -MemberType NoteProperty -Name "DownMins" -Value $intEventMins
        $objTemp|Add-Member -MemberType NoteProperty -Name "DownMins" -Value $intAdjustedMins
        $colSitesWithDownTime.Add($objTemp) | Out-Null
        LogIt "debug: colSitesWithDownTime.count=$($colSitesWithDownTime.count)"
    }
}

#--display the results
LogIt
LogIt "-Site Counts-"
LogIt "sites processed: $($colSitesProcessed.Count)"
LogIt "sites selected: $($colSitesSelected.Count)"
LogIt "sites with non-maintenance downtime: $($colSitesWithDownTime.Count)"
LogIt
LogIt "-Subtotals-"


#######################################################################
#
# loop through the sites selected collection and calc downtime
#
#######################################################################


ForEach ($objSite in $colSitesSelected) {

    #--get the site number from this collection member
    $strProcessedSite = $($objSite.Site)

    #--search for the site number in colSitesWithDownTime
    [bool]$boolFound=$FALSE
    ForEach ($objItem in $colSitesWithDownTime) {
        $strDownSite=$($objItem.Site)

        #--if it is found, calculate the downtime for the site
        If ($strDownSite -eq $strProcessedSite) {

            #--get the down minutes for this site
            $intSiteDownMins = $($objItem.DownMins)

            #--calculate downtime pct for this site
            $intSiteDownPct=$($intSiteDownMins/$intMinsInMonth)
            $intSiteUpPct=$(1-$intSiteDownPct)

            #--output a line showing the site and the calculated uptime
            #LogIt $($strDownSite, $intSiteDownMins, "{0:p2}" -f $intSiteUpPct, "{0:p2}" -f $intSiteDownPct)
            LogIt "$strDownSite,$intSiteDownMins,$("{0:p2}" -f $intSiteUpPct)"

            #--accumulate the total downtime minutes
            $intTotalDownMins+=$intSiteDownMins

            #--set the found flag
            $boolFound=$TRUE
            Break
        }
    }

    #--if it wasn't found in the down sites collection, display it as 100% uptime
    If (!$boolFound) {
            #--output a line showing the site and 100% uptime
            LogIt "$strProcessedSite,0,$("{0:p2}" -f 1)"
    }

}
LogIt

#--calculate average uptime for the entire system
$intTotalPossibleSiteUpMins=$($colSitesProcessed.Count * $intMinsInMonth)
$intAvgDowntimePct=$intTotalDownMins/$intTotalPossibleSiteUpMins
$intAvgUptimeAllSites=1-$intAvgDowntimePct

#--end


