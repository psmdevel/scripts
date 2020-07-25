#--get most recently written file, or directory

Param(
    [Parameter(Mandatory=$false,ParameterSetName="Type",Position=0)]
    [switch]$File,
    [Parameter(Mandatory=$false,ParameterSetName="Type",Position=1)]
    [switch]$Directory
)
$CWD = $PWD|Out-Null

if ($File)
    {
        $LATEST = gci $CWD -File |sort LastWriteTime|select -last 1
    }
if ($Directory)
    {
        $LATEST = gci $CWD -Directory |sort LastWriteTime|select -last 1
    }

if (!$File -and !$Directory)
    {
        $LATEST = gci $CWD -File |sort LastWriteTime|select -last 1
        if (!$LATEST)
            {
                $LATEST = gci $CWD -Directory |sort LastWriteTime|select -last 1
            }
    }
$LATEST