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

# count total hanles on computer
$handles = (Get-Process| Measure-Object Handles -Sum).Sum

# Monitoring output

$exit_code = $UNKNOWN
  
if ($null -ne $handles) {
	
	if ($handles -gt $critical_value) {
		$resultstring= 'Handles on '+ $ENV:COMPUTERNAME +' = '+ $handles
		$exit_code = $CRITICAL
	}
	elseif ($handles -gt $warning_value) {
		$resultstring= 'Handles on '+ $ENV:COMPUTERNAME +' = '+ $handles
		$exit_code = $WARNING
	}
	else{
		$resultstring= 'Handles on '+ $ENV:COMPUTERNAME +' = '+ $handles
		$exit_code = $OK
	}
}

Write-Host $resultstring
exit $exit_code
