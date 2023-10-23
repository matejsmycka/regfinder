<#
UNKNOWN - not found
OK - no ending certificates found
warning - certificates ends in $warning_value period
critical - certificates ends in $critical_value period
#>

# Shell arguments
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

# ASK STATUS
$backDays = -30

$fromDate = (Get-Date).AddDays($backDays)
$toWarningDate = (Get-Date).AddDays($warning_value)
$toCriticalDate = (Get-Date).AddDays($critical_value)
$certCritical = 0
$certWarning = 0
$endingCertString = ""
$resultstring = ""

#select all certs on server grouped by dnsname and ordered by expirate date
#$CertsOnServer = Get-ChildItem Cert:\LocalMachine\My -Recurse | Sort-Object -Property NotAfter -Descending | Group-Object -Property DNSNameList
$CertsOnServer = Get-ChildItem Cert:\LocalMachine\My -Recurse | Where-Object {$_.NotAfter -ge $fromDate -and $_.EnhancedKeyUsageList.ObjectId -eq '1.3.6.1.5.5.7.3.1'} | Sort-Object -Property NotAfter -Descending | Group-Object -Property Issuer
$numberOfCerts = $certsOnServer | Measure-Object | Select-Object -exp count

if ($null -ne $numberOfCerts) {

    $exit_code = $OK

    foreach ($certgroup in $certsOnServer) {
        #choose only newest certificate from each group
        $cert = $certgroup | Select-Object -ExpandProperty Group | Select-Object -First 1
        #Warning check
        if (($cert.NotAfter -gt $fromDate) -and ($cert.NotAfter -lt $toWarningDate)) {
            $endingCertString = "Certificate $($cert.Subject), issued by $($cert.Issuer) ending $($cert.NotAfter) | "
            $certWarning = 1
        }
        #Critical check
        if (($cert.NotAfter -gt $fromDate) -and ($cert.NotAfter -lt $toCriticalDate)) {
            $endingCertString = "Certificate $($cert.Subject), issued by $($cert.Issuer) ending $($cert.NotAfter) | "
            $certCritical = 1
        }
        
        $resultstring = $resultstring + $endingCertString
    }
} else {
    $resultstring='Hosts certificates cannot be accessed'
    $exit_code = $UNKNOWN
}

if ($certWarning -eq 1) {
    $exit_code = $WARNING
}
if ($certCritical -eq 1) {
    $exit_code = $CRITICAL
}
if ($exit_code -eq $OK) {
    $resultstring='All certificates are OK'
}

Write-Host $resultstring
exit $exit_code