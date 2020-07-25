#--Analyze Fields within a table and output the query to update field names without changing anything else about the table

#--Import the Invoke-Mysql.psm1 module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

#--Process the arguments
foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
        if ($L -eq '--table' -or $L -eq '-t') {$TABLE = $R}
        if ($L -eq '--master' -or $L -eq '-m') {$MASTER = $R}
    }

if (!$SID){echo "Specify site number with --site or -s";exit}
if (!$TABLE){echo "Specify tablename with --table or -t";exit}
if (!$MASTER){echo "Specify master database with --master or -m";exit}

#--Get the site information from ControlData
$SHOW = Invoke-MySQL -s=000 --query="select * from sitetab where siteid = $SID;"
$DBCLUST = $SHOW.db_cluster

#--Get the table description from the master database
$M_DESC = invoke-mysql --site=$SID --host=$DBCLUST --query="describe $MASTER.$TABLE;"|select field,type

#--Get the table description from the mobiledoc database
$T_DESC = invoke-mysql --site=$SID --host=$DBCLUST --query="describe $TABLE;"|select field,type

#--Compare field names and output the alter query

foreach ($M_NAME in $M_DESC)
    {
        foreach ($T_NAME in $T_DESC)
            {
                if ($T_NAME.field -eq $M_NAME.field)
                    {
                        if ($T_NAME.field -cne $M_NAME.field)
                            {
                                $T_FIELD = $T_NAME.field
                                $M_FIELD = $M_NAME.field 
                                $T_TYPE = $T_NAME.type
                                echo "ALTER TABLE $TABLE change ``$T_FIELD`` ``$M_FIELD`` $T_TYPE;"
                            }
                    }
            }
    }






