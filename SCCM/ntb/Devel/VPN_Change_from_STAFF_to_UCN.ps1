# Change routes to all MUNI public segment anf AOVPN segments
(Get-VpnConnection -Name "MU AlwaysOn VPN (Device tunnel)").routes | Remove-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)"
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "10.16.32.0/20" -PassThru
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "10.16.224.0/20" -PassThru
Add-VpnConnectionRoute -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DestinationPrefix "147.251.0.0/16" -PassThru

# Change DNS servers to DNS1 and DNS2
Set-VpnConnectionTriggerDnsConfiguration -ConnectionName "MU AlwaysOn VPN (Device tunnel)" -DnsSuffix ".ucn.muni.cz" -DnsIPAddress "147.251.16.91","147.251.16.92" -PassThru -Force

# Change server address
get-vpnconnection -Name "MU AlwaysOn VPN (Device tunnel)" | Set-VpnConnection -ServerList (New-VpnServerAddress -ServerAddress vpn2-ext.ucn.muni.cz -FriendlyName vpn2-ext.ucn.muni.cz) -ServerAddress vpn2-ext.ucn.muni.cz -DnsSuffix "ucn.muni.cz"

# Reconect VPN
rasdial /disconnect
rasdial "MU AlwaysOn VPN (Device tunnel)"