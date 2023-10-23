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
   [string]$path,
	 [Parameter(Mandatory=$True,Position=4)]
   [string]$extension
   )

Set-Variable OK 0 -option Constant
Set-Variable WARNING 1 -option Constant
Set-Variable CRITICAL 2 -option Constant
Set-Variable UNKNOWN 3 -option Constant


#
# ASK STATUS
#

$counter = Get-SmbOpenFile | Where-Object Path -Like "*.$Extension" | Select-Object -Property ClientComputerName -Unique | Measure-Object | Select-Object -ExpandProperty Count
$counters = @(Get-ChildItem -path $path -Recurse -Include *.$extension | Select-Object Length | Measure-Object -Property Length -sum -ave -max -min),
						@(Get-ChildItem -Path $path -Recurse -Include *.$extension | Select-Object LastWriteTime | Measure-Object -Property LastWriteTime -max -min)
$counter = $counters[0] | Select-Object -ExpandProperty Count
# Nagios output

$resultstring='The count of {0} files is unknown!' -f $Extension
$exit_code = $UNKNOWN
  
if ($null -ne $counter) {
	
	if ($counter -gt $critical_value) {
		$status_str= 'There are {0} {1} files on {2} in the {3} directory; Oldest file is from {4}' -f $counter,$extension,$ENV:COMPUTERNAME,$path,$counters[1].Minimum
		$exit_code = $CRITICAL
	}
	elseif ($counter -gt $warning_value) {
		$status_str= 'There are {0} {1} files on {2} in the {3} directory; Oldest file is from {4}' -f $counter,$extension,$ENV:COMPUTERNAME,$path,$counters[1].Minimum
		$exit_code = $WARNING
	}
	else{
		$status_str= 'There are {0} {1} files on {2} in the {3} directory; Oldest file is from {4}' -f $counter,$extension,$ENV:COMPUTERNAME,$path,$counters[1].Minimum
		$exit_code = $OK
	}
    	
	$perf_data= @('{3}_Count={0};{1};{2};' -f $counter,$warning_value,$critical_value,$extension)
	$perf_data+= @('{1}_SumTotalSizeTB={0};' -f ([math]::Round($counters[0].Sum/1TB,2)),$extension)
	$perf_data+= @('{3}_AveTotalSizeTB={0};{1};{2};{4};{5}' -f ([math]::Round($counters[0].Average/1GB,2)),'','',$extension,([math]::Round($counters[0].Minimum/1GB,2)),([math]::Round($counters[0].Maximum/1GB,2)))
	$resultstring= '{0} | {1} {2} {3}' -f $status_str,$perf_data[0],$perf_data[1],$perf_data[2]
}

Write-Host $resultstring
exit $exit_code
