#install SCCMclient
Start-Process "$PSScriptRoot\Config\ccmsetup.exe" -ArgumentList "/forceinstall /mp:sccm-01.ucn.muni.cz SMSMP=sccm-01.ucn.muni.cz DNSSUFFIX=ucn.muni.cz FSP=sccm-01.ucn.muni.cz" -PassThru | Wait-Process
Write-Host "SCCM klient instalace spustena." -ForegroundColor Green

#Check if it created directory
if((Test-Path "C:\Windows\ccmsetup") -and (Get-Service "ccmsetup")){
    Write-Host "SCCM Instalace probiha..." -ForegroundColor Green -NoNewline
    Read-Host
}else {
    Write-Host "SCCM Instalace neprobiha..." -ForegroundColor Red -NoNewline
    Read-Host
}