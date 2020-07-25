#--eBO Report, show sites with eBO, their current version/suite, and ebourl

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

$SITEARRAY = invoke-mysql -s=000 --query="select * from sitetab where status = 'active' and ebo_server like 'cognos%' or status = 'active' and ebo_server like 'vmhost%' order by siteid;"
$EBOLIST = @()

foreach ($SITE in $SITEARRAY)
    {
        $SID = $SITE.siteid
        $KEYWORDS = $SITE.keywords
        $DBCLUST = $SITE.db_cluster
        $DBUSER = "site" + $SID + '_DbUser'
        $DBPWD = $SITE.dbuser_pwd
        $EBOSRV = $SITE.ebo_server
        $EBOVERSION = Invoke-Mysql --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name  = 'eBOPackageVersion'"
        $EBOVERSION = $EBOVERSION.value
        $EBOURL = Invoke-MySQL  --site=$SID --host=$DBCLUST --user=$DBUSER --pass=$DBPWD --query="select value from itemkeys where name = 'ebourl';"
        $EBOURL = $EBOURL.value
        $EBOTABLE = New-Object System.Object
        $EBOTABLE | Add-Member -Type NoteProperty -Name Site -Value "$SID"
        $EBOTABLE | Add-Member -Type NoteProperty -Name eBO_Server -Value "$EBOSRV"
        $EBOTABLE | Add-Member -Type NoteProperty -Name eBO_Version -Value "$EBOVERSION"
        $EBOTABLE | Add-Member -Type NoteProperty -Name eBO_URL -Value "$EBOURL"
        $EBOLIST += $EBOTABLE
    }

$EBOLIST