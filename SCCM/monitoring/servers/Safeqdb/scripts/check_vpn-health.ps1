<#
UNKNOWN - not found
OK - connections
warning - current connections greater than warning value
critical - current connection greater than critical value
#>

Set-Variable OK 0 -option Constant
Set-Variable WARNING 1 -option Constant
Set-Variable CRITICAL 2 -option Constant
Set-Variable UNKNOWN 3 -option Constant


#
# ASK STATUS
#

$counter = Get-RemoteAccessHealth

# Nagios output

$resultstring='VPN HEALTH UNKNOWN' 
$exit_code = $UNKNOWN
  
if ($counter -ne $null) {
	
	if (($counter | select -exp HealthState) -contains "Error") {
		$status_str= 'VPN Health CRITICAL: ' + ($counter | Where healthstate -eq "Error" | select component, healthstate,operationstatus,id)
		$exit_code = $CRITICAL
	}
	elseif (($counter | select -exp HealthState) -contains "Unknown") {
		$status_str= 'VPN Health UNKNOWN ' + ($counter | Where healthstate -eq "Unknown" | select component, healthstate,operationstatus,id)
		$exit_code = $WARNING
	}
	else{
		$status_str= 'VPN Health OK'
		$exit_code = $OK
	}
    	
	$resultstring= "$status_str" 
}

Write-Host $resultstring
exit $exit_code
