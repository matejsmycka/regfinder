#kontroluje, jestli se neobjeví nějaká událost v Eventlogu v WinPakCommunicationConnector. Pokud ano, pošle SMS přes Nagios. 
#Po stanoveném intervalu bude považovat situaci za vyřešenou a v Nagiosu zezelená.

$mins = -6 #po 5 minutách kontroluje Nagios, takže aspoň 6 min rozdíl
$date = (Get-Date).AddMinutes($mins)
$A = Get-EventLog -Log WinPakCommunicationConnector -Newest 1

#$A.TimeGenerated
#$date

if ($A.timeGenerated -gt $date) 
    {
    Write-Output ('WinPAK Critical, last Eventlog Error ' + $A.TimeGenerated)
    Exit 2
    }
    else
    {
    Write-Output ('WinPAK ok, last Eventlog Error ' + $A.TimeGenerated)
    Exit 0
    }