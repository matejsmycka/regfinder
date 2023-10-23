Set-ExecutionPolicy -ExecutionPolicy Bypass

gpupdate /force

Start-Process certlm.msc

# Creating VPN profile 
& "$PSScriptRoot\InstallAlwaysOnVPN.bat"

# Install SCCM client
& "$PSScriptRoot\InstallSCCMclient.ps1"