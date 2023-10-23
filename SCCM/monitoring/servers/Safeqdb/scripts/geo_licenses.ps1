<#
UNKNOWN - not found
OK - connections
warning - current connections greater than warning value
critical - current connection greater than critical value
#>

#
# Shell arguments
#

[CmdletBinding()]
Param(
   [Parameter(Mandatory=$True,Position=1)]
   [int]$max
)

Set-Variable OK 0 -option Constant
Set-Variable WARNING 1 -option Constant
Set-Variable CRITICAL 2 -option Constant
Set-Variable UNKNOWN 3 -option Constant

#
# ASK STATUS
#
Set-Location "C:\Program Files\Harris\flexnetls-x64_windows-2017.08.0\enterprise\"
$clients = &".\flexnetlsadmin.bat" -server http://localhost:7070 -licenses
$row_clients = $clients | select-string -pattern "no_of_client"
$row_clients -match ".* \: ([0-9])*" | Out-Null
$counter = $Matches[1]

# Nagios output

$resultstring='Number of clients for ENVI SW Unknown' 
$exit_code = $UNKNOWN
  
if ($counter -ne $null) {
	
    if ($connections -ge $max) {
		$status_str= 'ENVI LICENCES EXCEEDED ('+ $counter +" out of $max)"
		$exit_code = $WARNING
	}
	else{
		$status_str= 'ENVI LICENCES OK ('+ $counter +" out of $max)"
		$exit_code = $OK
	}
    	
	$perf_data= "ENVI-SW_TAKEN_LICENCES=" + $counter + ';;;0;' + $max
    $resultstring= "$status_str  |  $perf_data " 
}

Write-Host $resultstring
exit $exit_code