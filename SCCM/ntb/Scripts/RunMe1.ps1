Set-ExecutionPolicy -ExecutionPolicy Bypass

# Aktivace Win 10 Edu vuci KMS serveru
& "$PSScriptRoot\ActivateWindows.ps1"

# Prejmenovani pocitace
& "$PSScriptRoot\RenameComputer.ps1"

