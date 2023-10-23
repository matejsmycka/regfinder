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
   [int]$critical_value,
	 [Parameter(Mandatory=$True,Position=3)]
   [string]$Extension
   )

Set-Variable OK 0 -option Constant
Set-Variable WARNING 1 -option Constant
Set-Variable CRITICAL 2 -option Constant
Set-Variable UNKNOWN 3 -option Constant


#
# ASK STATUS
#

$counter = Get-SmbOpenFile | Where-Object Path -Like "*.$Extension" | Select-Object -Property ClientComputerName -Unique | Measure-Object | Select-Object -ExpandProperty Count

# Nagios output

$resultstring='The count of SMB open files is unknown!'
$exit_code = $UNKNOWN
  
if ($null -ne $counter) {
	
	if ($counter -gt $critical_value) {
		$status_str= 'SMB {0} open {1} files: {2}' -f $ENV:COMPUTERNAME, $Extension, $counter
		$exit_code = $CRITICAL
	}
	elseif ($counter -gt $warning_value) {
		$status_str= 'SMB {0} open {1} files: {2}' -f $ENV:COMPUTERNAME, $Extension, $counter
		$exit_code = $WARNING
	}
	else{
		$status_str= 'SMB {0} open {1} files: {2}' -f $ENV:COMPUTERNAME, $Extension, $counter
		$exit_code = $OK
	}
    	
	$perf_data= 'SMB_OpenFiles={0};{1};{2};' -f $counter,$warning_value,$critical_value
	$resultstring= '{0} | {1}' -f $status_str,$perf_data
}

Write-Host $resultstring
exit $exit_code
