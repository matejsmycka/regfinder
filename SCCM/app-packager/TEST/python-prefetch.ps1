[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$LastVersion = (Invoke-WebRequest -Uri "https://www.python.org/downloads/windows/" | Select -ExpandProperty Links | where -Property innerText -like "Latest Python 3 Release*").innerText
[regex]$r = "Latest Python 3 Release - (.*) (.*)"
$Version = $r.Matches($LastVersion).Groups[2].Value	
$URL = "https://www.python.org/ftp/python/$Version/python-$Version`-amd64.exe"
Write-Host $Version
Write-Host $URL

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$LastVersion = wget https://www.rstudio.com/products/rstudio/download/ | Select -ExpandProperty Links |Where {$_.innerText -like "RStudio*Windows*64-bit*" -and $_.href -like "*.exe"}
$URL = $LastVersion.href
[regex]$r = "RStudio (.*) - .*"
$Version = $r.Matches($LastVersion.innerText).Groups[1].Value	
Write-Host $Version
Write-Host $URL

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$URL = "https://cran.rstudio.com/bin/windows/base/"
$LastVersion = (Invoke-WebRequest -Uri $URL | Select -ExpandProperty Links | where -Property innerText -like "Download * for Windows").href
[regex]$r = "R-(.*)-win.exe"
$Version = $r.Matches($LastVersion).Groups[1].Value	
$URL = $URL+$LastVersion
Write-Host $Version
Write-Host $URL