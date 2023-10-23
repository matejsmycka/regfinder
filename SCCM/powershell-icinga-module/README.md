# PowerShell Icinga Module
This script will help you programmatically add hosts and services to the Icinga monitoring.

## Configuration files Part
The configuration is almost identical with, e.g. Ansible   

### Standard ones
- contact-groups.json - definition of Contact groups   
Support for nested groups - just add `vars: {"priority": number}` key to register groups in specific order.
- host-groups.json - definition of Host groups
- hosts.json - definition of Hosts
- notifications.json
- service-groups.json
- services.json
- users.json
- endpoints.json - definition of API endpoint URLs   

In general keys that could be used are documented in the [official documentation](https://icinga.com/docs/icinga2/latest/doc/09-object-types/).

### Specials
Configurations that are not related to Icinga objects.
- service-sets.json - defining a set of services at once. If the host has `service-sets: ["default"]` and service-set `default` consist of cpuload, memuse, uptime - the host will have these services without naming them specifically.
- notification-sets.json - defining a set of notifications. Same as services.
- vault.json – storage for your API credentials here

## Scripts
### pswicinga.ps1
Main functions and classes

### auto-configuration.ps1
Consists of functions that will use configurations files, read them, parse them and call functions from `pswicinga.ps1`. You can modify this so it will match your needs.   
Example usage if you want to refresh configuration that is in the Icinga to match configuration files:
```powershell
. .\auto-configuration.ps1 # to load configuration files after change
Unregister-IcingaAllObjects # to unregister your objects from Icinga but note that if you remove the object from a configuration file, the object will not be removed from Icinga. There is a logic of the absent state that will be shown below.
Register-IcingaAllObjects # this will register all objects from configuration files to Icinga.

```
Objects that will have the following key in their configuration file:
```json
"vars": {
    "state": "absent"
}
```
The object will be removed from Icinga but they will not be registered back. This is useful if you want to remove something from Icinga.

## Manually 
You can use `pswicinga.ps1` functions to build your own handling commands and data structure to keep the configuration of your environment.

Basic call to register host to the Icinga:
```powershell
$Hashtable = @{
    "display_name" = "uvt-server"
    "address" = "4.2.4.2"
    "groups" = @("group1", "group2")
    "check_command" = "hostalive"
    "vars" = @{
        "note" = "This is my super server!"
        "dohled" = "Z2"
    },
    "check_interval" = 90
}
Register-IcingaHost -Name "hostname" -data $Hashtable
Unregister-IcingaHost -Name "hostname"
```
For service
```powershell
$Hashtable = @{
    "display_name" = "web"
    "check_command" = "http"
    "vars" = @{
        "http_vhost" = "domain.cz"
    },
    "check_interval" = 60
    "retry_interval" = 15
    "groups" = @("service-group1")        
}
Register-IcingaService -Name "web" -ServerName "hostname.ics.muni.cz" -Data $Hashtable
Unregister-IcingaService -name "web" -ServerName "hostname.ics.muni.cz"
```