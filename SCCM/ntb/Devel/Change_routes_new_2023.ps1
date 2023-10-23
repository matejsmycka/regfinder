(Get-VpnConnection -Name "MU AlwaysOn VPN (Device tunnel)").routes | Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)"
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "10.16.32.0/20" -PassThru
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "10.16.224.0/20" -PassThru
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.0.0/16" -PassThru