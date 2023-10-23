# check if new version si available
$nsclient_folder = 'C:\Program Files\NSClient++\'
$work_url = "https://sccm-01.ucn.muni.cz/monitoring"

$ErrorActionPreference = "Continue"

# Get by name
$remote_hash = Invoke-WebRequest "$work_url/versions.json" -UseBasicParsing | Select-Object -exp content | ConvertFrom-Json | Select-Object -exp $ENV:COMPUTERNAME -ErrorAction SilentlyContinue

# Fallback if there is not specific config file
if (-not($remote_hash.includes."nsclient.ini")){
    $remote_hash = Invoke-WebRequest "$work_url/versions.json" -UseBasicParsing | Select-Object -exp content | ConvertFrom-Json | Select-Object -exp "default"
}

$local_hash = Get-FileHash -Path (Join-Path $nsclient_folder "nsclient.ini") -Algorithm MD5 | Select-Object -ExpandProperty hash

# compare hash of version on server and local version of nsclient.ini
if ($remote_hash.includes."nsclient.ini" -eq $local_hash){
    $true
} else {
    $false
}