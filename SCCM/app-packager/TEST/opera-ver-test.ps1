$LastVersions = ((Invoke-WebRequest "https://download1.operacdn.com/pub/opera/desktop/" | Select-Object -ExpandProperty Links | where -Property OuterText -Like "*/").href.trim("/") | select -last 10 | %{[System.Version]$_} | sort -Descending)
foreach ($Version in $LastVersions){
    $Version = $Version.ToString()
    try {
        $ExecutableFile = Invoke-webrequest -Uri "https://download1.operacdn.com/pub/opera/desktop/$Version/win/" | Select-Object -ExpandProperty Links | Where -Property OuterText -Like "Opera_$($Version)_Setup_x64.exe"
        $URL = "https://download1.operacdn.com/pub/opera/desktop/$Version/win/Opera_$Version`_Setup.exe"
        break
    } catch {
        Write-Host "[Downloading: Opera] Wrong version: $Version, skipping."
        continue
    }
}