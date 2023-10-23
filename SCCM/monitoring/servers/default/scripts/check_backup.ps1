#Add-Pssnapin Windows.serverbackup

$backup = Get-WBSummary
$LastSuccBackupTime =$backup.LastSuccessfulBackupTime

$cas = (get-date) - (new-timespan -day 1 -hour 2)

$computer_name = hostname 

if ($LastSuccBackupTime -lt $cas) 
{
  write-host "WARN: Backup of $computer_name - WARNING!!!"
  write-host "Last Succesful Backup Time:" $LastSuccBackupTime
  exit 1
}
else
{
  write-host "OK: Backup of $computer_name - OK"
  write-host "Last Succesful Backup Time:" $LastSuccBackupTime
  exit 0
}