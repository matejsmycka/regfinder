Param (
    $username,
    $pw
)
New-PSDrive -Name MONITORING -PSProvider FileSystem -Root "\\sccm-01.ucn.muni.cz\monitoring" -Credential (New-Object System.Management.Automation.PSCredential $username, (ConvertTo-SecureString $pw -AsPlainText -Force))
Remove-Item "monitoring:\*" -Force -Recurse
Copy-Item ".\temp-monitoring\*" "monitoring:\" -exclude ("run.ps1", "compute-hash.ps1", "driver.ps1", "check.ps1") -force -recurse
Remove-PSDrive -Name MONITORING