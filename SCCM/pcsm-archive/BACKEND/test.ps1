."C:\pcsm_backend\functions_include.ps1"


$computers="pc124.ups.ucn.muni.cz,pc125.ups.ucn.muni.cz,pc126.ups.ucn.muni.cz"
$start = Get-Date -Format "2014-06-04 19:18:00"
$end =  Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$mailTo = "cuchran@ics.muni.cz"
$lokalitaName = "tet lokalita"
$poznamka = "test poznamka"
$operacia = "test operacia"




function mailCPS{
     param (
		    [Parameter(Mandatory = $True, Position = 1)]
		    [string]$mailTo,
		    [Parameter(Mandatory = $True, Position = 2)]
		    [string]$dateFrom,
		    [Parameter(Mandatory = $True, Position = 3)]
		    [string]$dateTo,
            [Parameter(Mandatory = $True, Position = 4)]
		    [string]$operacia,
            [Parameter(Mandatory = $True, Position = 5)]
		    [string]$poznamka,
            [Parameter(Mandatory = $True, Position = 6)]
		    [string]$lokalitaName,
            [Parameter(Mandatory = $True, Position = 7)]
		    [string]$computers
	 )  
	
    [string]$log="Log strojov: <br><br>"

    $computersSplit = $computers.Split(",")

	foreach ($pc in $computersSplit){

        $info = New-Object System.Data.DataSet
	    $info = mysqlQuerySelect -query "SELECT * FROM logs WHERE computer_name='$pc' AND first_check>='$dateFrom' AND last_check<='$dateTo' AND process='scheduler' ORDER BY computer_name"
	    $dataTable = new-object System.Data.DataTable
	    $dataTable = $info.Tables[0] 
        $computerName = $dataTable.rows[0].computer_name 
        $computer_status = $dataTable.rows[0].status
        if($dataTable.rows[0] -ne $null){
            $log += "$computerName - $computer_status <br>"
        }
    }

    Logger -type "CHECK" -text $log

    #MAIL to CPSADM
    send-mailmessage -from "PCSM <pcsm@ics.muni.cz>" -to "<$mailTo>" -subject "PCSM - Uskutocnenie planovanej ulohy" -BodyAsHtml -body "V case <b>$dateFrom - $dateTo</b> bola na lokalite: <b>$lokalitaName</b> spustena naplanovana operacia: <b>$operacia $poznamka</b>. Log z operacie je dostupny v aplikacii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b><br><br>$log<br>Tento email je automaticky generovany aplikaciou PCSM." -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
		
	

}	

mailCPS -mailTo "cuchran@ics.muni.cz" -dateFrom $start -dateTo $end -operacia "Test funkcie" -poznamka "Poznamka test" -lokalitaName "Lokalita 1" -computers $computers
