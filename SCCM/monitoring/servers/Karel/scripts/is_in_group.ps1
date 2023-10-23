<#
    Checks wether $targetName is not member of Active Directory group $groupDN.

    Usage:
    .\is_in_group.ps1 "CN=InsideCPS,OU=System,OU=MU,DC=ucn,DC=muni,DC=cz" "Domain Admins"

    Returns:
    0 - is not a member
    1 - is a member
    2 - error
#>
param(
    # DN of the Active Directory group to search in
    [Parameter(Mandatory=$true)]
    [string] $groupDN,
    # Name of the presumed Active Directory group member
    [Parameter(Mandatory=$true)]
    [string] $targetName
)

#Import-Module ActiveDirectory

try
{
    $member = Get-ADGroupMember -Identity $groupDN | Where-Object { $_.name -eq $targetName }
}
catch
{
    # Error
    Write-Host "ERROR: $($_.Exception.Message)"
    Exit 2
}

if ($member -ieq $null) 
{
    # Not found
    Write-Host "OK: $targetName not in $groupDN"
    Exit 0
}
else
{
    # Found
    Write-Host "WARN: $targetName in $groupDN"
    Exit 1
}
