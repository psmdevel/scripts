param(
$failureVar
)

$to = "psmsupport@psmnv.com","admin@psmnv.com"
$from = "root@$env:COMPUTERNAME.mycharts.md"
$subject = "$failureVar on $env:COMPUTERNAME.mycharts.md"
$body = "OpenManage has detected $failureVar on $env:COMPUTERNAME.mycharts.md. Please investigate."
$smtp = "mail"

Send-MailMessage -To $to -From $from -Subject $subject -Body $body -SmtpServer $smtp
