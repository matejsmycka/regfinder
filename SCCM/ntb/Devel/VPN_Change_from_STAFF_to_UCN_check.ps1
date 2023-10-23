# List all routes
(Get-VpnConnection -Name "MU AlwaysOn VPN (Device tunnel)").routes

# List DNS servers
Get-VpnConnectionTrigger -name "MU AlwaysOn VPN (Device tunnel)" | ft

# Get VPN info
Get-VpnConnection -name "MU AlwaysOn VPN (Device tunnel)"