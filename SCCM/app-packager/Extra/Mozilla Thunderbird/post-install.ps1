Param (
    $Version
)
New-Item -Path HKLM:\Software\ICSMUSW\ -name Thunderbird -Force
New-ItemProperty -Path HKLM:\Software\ICSMUSW\Thunderbird -name Version -Value $Version -Force