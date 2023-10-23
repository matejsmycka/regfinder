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
   [int]$warning_value,
   [Parameter(Mandatory=$True,Position=2)]
   [int]$critical_value
   )

Set-Variable OK 0 -option Constant
Set-Variable WARNING 1 -option Constant
Set-Variable CRITICAL 2 -option Constant
Set-Variable UNKNOWN 3 -option Constant


#
# ASK STATUS
#

$counter = Get-RemoteAccessConnectionStatistics | Measure-Object | Select-Object -exp count

# Nagios output

$resultstring='VPN CONNECTIONS COUNT UNKNOWN' 
$exit_code = $UNKNOWN
  
if ($null -ne $counter) {
	
	if ($connections -gt $critical_value) {
		$status_str= 'CONNECTIONS CRITICAL '+ $ENV:COMPUTERNAME +' connections '+ $counter
		$exit_code = $CRITICAL
	}
	elseif ($connections -gt $warning_value) {
		$status_str= 'CONNECTIONS WARNING '+ $ENV:COMPUTERNAME +' connections '+ $counter
		$exit_code = $WARNING
	}
	else{
		$status_str= 'CONNECTIONS OK '+ $ENV:COMPUTERNAME +' connections '+ $counter
		$exit_code = $OK
	}
    	
	$perf_data= "VPN-Connections=" + $counter + ';' + $warning_value + ';' + $critical_value + "; "
	$resultstring= "$status_str  |  $perf_data " 
}

Write-Host $resultstring
exit $exit_code
