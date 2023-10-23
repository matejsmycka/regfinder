
 <#
Nagion plugin check status of VMware tools installed at the local machine
#>

New-Variable retOK -option Constant -value 0
New-Variable retWarning -option Constant -value 1
New-Variable retCritical -option Constant -value 2
New-Variable retUnknown -option Constant -value 3


$tools_checker = 'C:\Program Files\VMware\VMware Tools\VMwareToolboxCmd.exe'
$ret_code = $retOK

#Write-Output ("VMwareTools status: ")

# check for VM toolbox presence
If (-Not (Test-Path -LiteralPath $tools_checker -PathType Leaf)) {
  Write-Output ("WARN: Toolbox does not exist at `'" + $tools_checker + "`'")
  $ret_code = $retCritical
  Exit $ret_code
}

# get VMtools status
$vmtools_status = & $tools_checker upgrade status | Out-String
$vmtools_status = $vmtools_status.Trim()
If($vmtools_status -ine 'VMware Tools are up-to-date.') {
  $ret_code = $retCritical
  Write-Output ("ERROR: `'" + $vmtools_status + "`'")
} Else {
  Write-Output ("OK: `'" + $vmtools_status + "`'")
}

Exit $ret_code
