#--db_rsync_pt1 summary email
Import-Module $DRIVE\scripts\sources\_functions.psm1 -Force

$date = [DateTime]::Today.AddDays(-2).ToString("yyyy-MM-dd")
$DATE2 = $date.ToString()
$HOSTNAME = hostname
$TECH_ARRAY = @("andy@psmnv.com", "eric.robinson@psmnv.com", "joe.dilorenzo@psmnv.com")
$TECH1 = (whoami).split('\')[1]
#$TECH1 = $TECHtmp#.split('\')[1]
if ($TECH1 -eq 'allean2') {$TECH = $TECH_ARRAY[0]}
#$date = ($date).AddDays(-1)
$BACKUPS = @()
$db_store_pt1 = Invoke-MySQL -Site 000 -query "select * from backup_log_rsync where start_time > '$date%' order by src_cluster;"
foreach ($DBCLUSTER in $db_store_pt1)
    {
        $BACKUPLOG = New-Object system.object
        $CLUSTER = $DBCLUSTER.src_cluster 
        $SERVER = $DBCLUSTER.src_server
        $SCRIPT = $DBCLUSTER.script_version
        $SITECOUNT = $DBCLUSTER.sites_selected
        $RSYNCCOUNT = $DBCLUSTER.sites_rsynced
        $DIFFERENCE = $SITECOUNT - $RSYNCCOUNT
        $START = $DBCLUSTER.start_time
        $END = $DBCLUSTER.end_time
        $DURATION = ($DBCLUSTER.duration).replace('hours','hrs')
        $FILESCOUNTED = $DBCLUSTER.files_counted
        $FILESUPDATED = $DBCLUSTER.files_updated
        $BYTESXFERRED = $DBCLUSTER.bytes_transferred
        $BYTESCOUNTED = $DBCLUSTER.bytes_counted
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Cluster -Value "$CLUSTER"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Server -Value "$SERVER"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Script -Value "$SCRIPT"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Sites -Value "$SITECOUNT"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Rsynced -Value "$RSYNCCOUNT"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Diff -Value "$DIFFERENCE"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name StartTime -Value "$START"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name EndTime -Value "$END"
        $BACKUPLOG | Add-Member -Type NoteProperty -Name Duration -Value "$DURATION"
        #$BACKUPLOG | Add-Member -Type NoteProperty -Name FilesCounted -Value "$FILESCOUNTED"
        #$BACKUPLOG | Add-Member -Type NoteProperty -Name FilesUpdated -Value "$FILESUPDATED"
        #$BACKUPLOG | Add-Member -Type NoteProperty -Name BytesCounted -Value "$BYTESCOUNTED"
        #$BACKUPLOG | Add-Member -Type NoteProperty -Name BytesTransferred -Value "$BYTESXFERRED"
        #$BACKUPLOG | Add-Member -Type NoteProperty -Name RsyncedSites -Value "$RSYNCCOUNT"
        $BACKUPS += $BACKUPLOG
    }
$BACKUPS|ft *
$BODY = $BACKUPS|ft * -AutoSize|Out-String
Send-MailMessage -To "$TECH <$TECH>" -From "db_backup_pt1_summary@$HOSTNAME <$HOSTNAME@mycharts.md>" -SmtpServer "mail" -Subject "db_backup_pt1_summary $DATE2" -Body $BODY
#$db_store_pt1