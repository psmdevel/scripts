#--Import Invoke-MySQL module
$DRIVE = (Get-Location).Drive.Root
Import-Module $DRIVE\scripts\invoke-mysql.psm1 -Force

foreach ($ARG in $ARGS)
    {
        $L,$R = $ARG -split '=',2
        if ($L -eq '--site' -or $L -eq '-s') {$SID = $R}
    }

$SHOW = Invoke-MySQL -s=000 --query="select s.*,a.a1,a.a2 from sitetab s inner join app_clusters a where siteid=$SID and a.id=s.app_cluster_id;"
$APPARRAY = @()
$APPARRAY += $SHOW.a1
$APPARRAY += $SHOW.a2
if ($SHOW.interface_server)
    {
        $APPARRAY += $SHOW.interface_server
    }

Write-Host "Checking AJP for site$SID "

foreach ($APP in $APPARRAY)
    {
        if ($APP -like 'app*')
            {
                if (Test-Path \\$APP\site$SID\tomcat8) 
                    { 
                        $TOMCATDIR = 'tomcat8' 
                    }
                        else
                            {
                                if (Test-Path \\$APP\site$SID\tomcat7) 
                                    { 
                                        $TOMCATDIR = 'tomcat7' 
                                    }
                                        else 
                                            {
                                                if (Test-Path \\$APP\site$SID\tomcat6) 
                                                    { 
                                                        $TOMCATDIR = 'tomcat6' 
                                                    }
                                            }
                            }
                $PATH = "\\$APP\site$SID\$TOMCATDIR\conf\server.xml"
            }
        if ($APP -like 'lab*')
            {
                if (Test-Path "\\$APP\c$\alley\site$SID\tomcat8\conf\server.xml")
                    {
                        $PATH = "\\$APP\c$\alley\site$SID\tomcat8\conf\server.xml"
                    }
                        else
                            {
                                if (Test-Path "\\$APP\c$\alley\site$SID\$TOMCATDIR\conf\server.xml")
                                        {
                                            $PATH = "\\$APP\c$\alley\site$SID\$TOMCATDIR\conf\server.xml"
                                        }
                            }

            }
        write-host -NoNewline "Checking $APP"
        if (Test-Path $PATH)
            {
                [xml]$xml = Get-Content -Path $PATH
                $xml.SelectNodes("//Connector")|ForEach-Object {
                        if ($_.protocol -like 'ajp*')
                            {
                                Write-Host -NoNewline "Updating $APP"
                                $nodeToComment = $_
                                $comment = $xml.CreateComment($nodeToComment.outerxml)
                                $nodeToComment.parentnode.replacechild($comment, $nodeToComment)
                                $xml.save("$PATH")
                            }
                    }
                [xml]$xml2 = Get-Content -Path $PATH
                $xml2.SelectNodes("//Connector")|ForEach-Object {
                        if ($_.protocol -like 'ajp*')
                            {
                                Write-Host -ForegroundColor Red "[FAIL]"
                            }
                                else
                                    {
                                        Write-Host -ForegroundColor Green "[OK]"
                                    }
                    }
            }
                else
                    {
                        Write-Host "could not access $PATH"
                    }
    }