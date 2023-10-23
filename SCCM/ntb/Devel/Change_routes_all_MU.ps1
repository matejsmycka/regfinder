Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.16.64/27" -PassThru
Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.63.64/28" -PassThru
Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.12.192/26" -PassThru
Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.12.80/28" -PassThru
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.0.0/16" -PassThru
