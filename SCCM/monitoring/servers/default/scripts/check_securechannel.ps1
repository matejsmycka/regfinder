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

$status = Test-ComputerSecureChannel

# Nagios output

$resultstring='Chennel status unknown' 
$exit_code = $UNKNOWN
  
if ($null -ne $status) {
	if ($status -eq $false) {
		$status_str= 'Secure Channel DOWN'
		$exit_code = $CRITICAL
	}
	else{
		$status_str= 'Secure Channel OK'
		$exit_code = $OK
	}
    	
	$resultstring= "$status_str" 
}

Write-Host $resultstring
exit $exit_code
