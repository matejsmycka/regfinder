# Include backend
. .\pswicinga.ps1

# Authenticate API requests
# It's possible to add your own endpoints in endpoints.json.
# [IcingaAPI] $Global:endpoint = [IcingaAPI]::new("vault", "demo/monitor")
[IcingaAPI] $Global:endpoint = [IcingaAPI]::new("vault")

# Load config files to hashtables
$IcingaCurrentObjects = @{
    hostgroups = Get-IcingaObjects -ObjectType "host-groups"
    contactgroups = Get-IcingaObjects -ObjectType "contact-groups"
    contacts = Get-IcingaObjects -ObjectType "users"
    hosts = Get-IcingaObjects -ObjectType "hosts"
    service_sets = Get-IcingaObjects -ObjectType "service-sets"
    services = Get-IcingaObjects -ObjectType "services"
    notifications = Get-IcingaObjects -ObjectType "notifications"
    notification_sets = Get-IcingaObjects -ObjectType "notification-sets"
    servicegroups = Get-IcingaObjects -ObjectType "service-groups"
}

function Write-Message {
    Param (
        $Message
    )
    Write-Host $("{0} {1} {2}" -f "[#################", $Message, "#################]") -BackgroundColor DarkYellow -ForegroundColor Black -NoNewline
    Write-Host
}

# Registration and unregistration of Icinga objects.
# Order of operations
# Unregister: Notifications, Services, Service Groups, Hosts, HostGroups, Contacts, ContactGroups
# Register: ContactGroups, Contacts, HostGroups, Hosts, Service Groups, Services, Notifications
####################################
## Unregister part
####################################

function Unregister-IcingaAllServiceGroups {
    Write-Message "Unregistering Service Groups."
    $IcingaCurrentObjects["servicegroups"].Keys | ForEach-Object {
        Unregister-IcingaServiceGroup -Name $_ -Data $IcingaCurrentObjects["servicegroups"][$_]
    }
}
function Unregister-IcingaAllHosts {
    Write-Message "Unregistering Hosts, Services and Notifications from Icinga"
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        Unregister-IcingaHost -Name $_ -Data $IcingaCurrentObjects["hosts"][$_] -Cascade
    }
}
function Unregister-IcingaAllHostGroups {
    Write-Message "Unregistering Host Groups from Icinga"
    $IcingaCurrentObjects["hostgroups"].Keys | ForEach-Object {
        Unregister-IcingaHostGroup -Name $_ -Data $IcingaCurrentObjects["hostgroups"][$_]
    }
}
function Unregister-IcingaAllContacts {
    Write-Message "Unregistering Contacts from Icinga"
    $IcingaCurrentObjects["contacts"].Keys | ForEach-Object {
        Unregister-IcingaContact -Name $_ -Data $IcingaCurrentObjects["contacts"][$_]
    }
}
function Unregister-IcingaAllContactGroups {
    Write-Host "Unregistering Contact Groups from Icinga"
    $Keys = $IcingaCurrentObjects["contactgroups"].Keys | Sort-Object -Property @{Expression={[int]$IcingaCurrentObjects["contactgroups"][$_]["vars"].Priority}} -Descending
    $Keys | ForEach-Object {
        Unregister-IcingaContactGroup -Name $_ -Data $IcingaCurrentObjects["contactgroups"][$_]
    }
}
function Unregister-IcingaAllServices {
    Write-Message "Unregistering Services"
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        $ServerName = $_
        
        $services = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "services" -ObjectTypeSets "service_sets"
    
        $services | ForEach-Object {
            Unregister-IcingaService -Name $_ -ServerName $ServerName -Data $IcingaCurrentObjects["services"][$_] -Cascade
        }
    }
}
function Unregister-IcingaAllNotifications {
    Param (
        [string]$hostname
    )
    Write-Message "Registering Host Notifications"
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        $ServerName = $_
    
        $host_notifications = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "notifications" -ObjectTypeSets "notification_sets"
        $host_notifications | ForEach-Object {
            Unregister-IcingaNotification -Name $_ -ServerName $ServerName -Type "host" -Data $IcingaCurrentObjects["notifications"][$_].Clone()
        }
    
        $services = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "services" -ObjectTypeSets "service_sets"
        $services | ForEach-Object {
            $ServiceName = $_
            $notifications = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["services"][$_] -ObjectType "notifications" -ObjectTypeSets "notification_sets"
            $notifications | ForEach-Object {
                Unregister-IcingaNotification -Name $_ -ServerName $ServerName -ServiceName $ServiceName -Type "service" -Data $IcingaCurrentObjects["notifications"][$_].Clone()
            }
        }
    
    }
}
function Unregister-IcingaAllObjects {
    Unregister-IcingaAllNotifications
    Unregister-IcingaAllServices
    Unregister-IcingaAllServiceGroups
    Unregister-IcingaAllHosts
    Unregister-IcingaAllHostGroups
    Unregister-IcingaAllContacts
    Unregister-IcingaAllContactGroups
}

####################################
## Register part
####################################
function Register-IcingaAllContactGroups {
    Write-Message "Registering Contact Groups to Icinga"
    ($IcingaCurrentObjects["contactgroups"].Clone()).Keys | ForEach-Object {
        if ($IcingaCurrentObjects["contactgroups"][$_]["vars"] -and $IcingaCurrentObjects["contactgroups"][$_]["vars"]["state"] -eq "absent"){
            $IcingaCurrentObjects["contactgroups"].Remove($_)
        }
    }
    $Keys = $IcingaCurrentObjects["contactgroups"].Keys | Sort-Object -Property @{Expression={[int]$IcingaCurrentObjects["contactgroups"][$_]["vars"].Priority}}
    $Keys | ForEach-Object {
        Register-IcingaContactGroup -Name $_ -Data $IcingaCurrentObjects["contactgroups"][$_]
    }
}
function Register-IcingaAllContacts {
    Write-Message "Registering Contacts to Icinga"
    ($IcingaCurrentObjects["contacts"].Clone()).Keys | ForEach-Object {
        if ($IcingaCurrentObjects["contacts"][$_]["vars"] -and $IcingaCurrentObjects["contacts"][$_]["vars"]["state"] -eq "absent"){
            $IcingaCurrentObjects["contacts"].Remove($_)
        }
    }
    $IcingaCurrentObjects["contacts"].Keys | ForEach-Object {
        Register-IcingaContact -Name $_ -Data $IcingaCurrentObjects["contacts"][$_]
    }
}
function Register-IcingaAllHostGroups {
    Write-Message "Registering HostGroups"
    ($IcingaCurrentObjects["hostgroups"].Clone()).Keys | ForEach-Object {
        if ($IcingaCurrentObjects["hostgroups"][$_]["vars"] -and $IcingaCurrentObjects["hostgroups"][$_]["vars"]["state"] -eq "absent"){
            $IcingaCurrentObjects["hostgroups"].Remove($_)
        }
    }
    $IcingaCurrentObjects["hostgroups"].Keys | ForEach-Object {
        Register-IcingaHostGroup -Name $_ -Data $IcingaCurrentObjects["hostgroups"][$_]
    }
}
function Register-IcingaAllHosts {
    Write-Message "Registering Hosts"
    ($IcingaCurrentObjects["hosts"].Clone()).Keys | ForEach-Object {
        if ($IcingaCurrentObjects["hosts"][$_]["vars"] -and $IcingaCurrentObjects["hosts"][$_]["vars"]["state"] -eq "absent"){
            $IcingaCurrentObjects["hosts"].Remove($_)
        }
    }
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        Register-IcingaHost -Name $_ -Data $IcingaCurrentObjects["hosts"][$_]
    }
}
function Register-IcingaAllServiceGroups {
    Write-Message "Registering Service Groups"
    $IcingaCurrentObjects["servicegroups"].Keys | ForEach-Object {
        Register-IcingaServiceGroup -Name $_ -Data $IcingaCurrentObjects["servicegroups"][$_]
    }
}
function Register-IcingaAllServices {
    Write-Message "Registering Services"
    ($IcingaCurrentObjects["servicegroups"].Clone()).Keys | ForEach-Object {
        if ($IcingaCurrentObjects["servicegroups"][$_]["vars"] -and $IcingaCurrentObjects["servicegroups"][$_]["vars"]["state"] -eq "absent"){
            $IcingaCurrentObjects["servicegroups"].Remove($_)
        }
    }
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        $ServerName = $_
        
        $services = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "services" -ObjectTypeSets "service_sets"
    
        $services | ForEach-Object {
            Register-IcingaService -Name $_ -ServerName $ServerName -Data $IcingaCurrentObjects["services"][$_]
        }
    }
}
function Register-IcingaAllNotifications {
    #Invoke-IcingaCurrentObjectRefresh
    Write-Message "Registering Host Notifications"
    $IcingaCurrentObjects["hosts"].Keys | ForEach-Object {
        $ServerName = $_
    
        $host_notifications = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "notifications" -ObjectTypeSets "notification_sets"
        $host_notifications | ForEach-Object {
            Register-IcingaNotification -Name $_ -ServerName $ServerName -Data $IcingaCurrentObjects["notifications"][$_].Clone() -Type "host"
        }
    
        $services = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["hosts"][$_] -ObjectType "services" -ObjectTypeSets "service_sets"
        $services | ForEach-Object {
            $ServiceName = $_
            $notifications = Get-IcingaObjectsFromVars -Object $IcingaCurrentObjects["services"][$_] -ObjectType "notifications" -ObjectTypeSets "notification_sets"
            $notifications | ForEach-Object {
                Register-IcingaNotification -Name $_ -ServerName $ServerName -ServiceName $ServiceName -Data $IcingaCurrentObjects["notifications"][$_].Clone() -Type "service"
            }
        }
    
    }
}
function Register-IcingaAllObjects {
    Register-IcingaAllContactGroups
    Register-IcingaAllContacts
    Register-IcingaAllHostGroups
    Register-IcingaAllHosts
    Register-IcingaAllServiceGroups
    Register-IcingaAllServices
    Register-IcingaAllNotifications
}

