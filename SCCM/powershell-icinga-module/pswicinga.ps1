# Some needed confifuration
$Global:IcingaObjects = "$(Get-Location)\configurations\"
$Global:IcingaTestOnly = $false

enum IcingaObjectType {
    Host = 0
    Service = 1
    HostGroup = 2
    ContactGroup = 3
    ServiceGroup = 4
    Contact = 5
    Notification = 6
    Dependency = 7
}

class IcingaAPI {
    [string]$Instance = "monitor"
    [System.Management.Automation.PSCredential]$creds

    IcingaAPI([string]$path){
        $this.Authenticate($path)
    }
    IcingaAPI([string]$path, [string]$Instance){
        $this.Authenticate($path)
        $this.Instance = $Instance
    }

    [void]Authenticate($file) {
        $account = Get-IcingaObjects -ObjectType $file
        Write-Debug "Authenticating as $($account.username)"
        $cred_message = "Enter valid ICINGA API account credentials."
        if (-not($this.creds.username -eq $account.username)){
            if ($account.username -and $account.password){
                $secpasswd = ConvertTo-SecureString $account.password -AsPlainText -Force
                $this.creds = New-Object System.Management.Automation.PSCredential ($account.username, $secpasswd)
            } elseif($account.username) {
                $this.creds = Get-Credential -UserName $account.username -Message $cred_message
            } else {
                $this.creds = Get-Credential -Message $cred_message
            }
            if (-not($this.creds)){
                #Write-Error "No credentials were entered."
                throw "No credentials entered"
            }
        }
    }
    [Hashtable]Call([string]$URI, [string]$Method, [string]$body){
        $header = @{"Accept"="application/json"}
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $URI = $this.GetIcingaInstanceURL()+$URI
        Write-Debug "Calling request to `nURL: $URI`nMethod: $Method"
        $h = @{}
        If ($Method -eq "GET"){
            $h["status"] = Invoke-RestMethod -Uri $URI -ContentType "application/json" -Credential $this.creds -Headers $header -ErrorAction SilentlyContinue
            return $h
        }
        Write-Debug "Body: $body"
        $h["status"] = Invoke-RestMethod -Uri $URI -ContentType "application/json" -Method $Method -Credential $this.creds -Headers $header -Body $body -ErrorAction SilentlyContinue
        Write-Debug "Output: "
        Write-Debug ($h["status"] | Out-String)
        return $h
    }

    [string]GetIcingaInstanceURL() {
        $Instances = Get-IcingaObjects -ObjectType "endpoints"
        return $Instances[$this.Instance]
    }
}
<#
# Base class for IcingaObjects
#>
class IcingaObject {
    [String]$Name
    [hashtable]$Data
    [String]$URI
    static [IcingaObjectType]$ObjectType
    [String]$Pattern
    [array]$Format

    IcingaObject([String]$name, [hashtable]$data){
        if ([String]::IsNullOrEmpty($name)){
            throw "Object name should not be empty!"
        }
        if ($data.Count -eq 0){
            throw "Object data should not be empty!"
        }
        $this.name = $name
        $this.Data = $data
        $this.Pattern = "{0} {1} '{2}'"
        $this.Format = @("Action", [IcingaObjectType].GetEnumName($this.ObjectType), $name)
    }

    hidden [void]SerializeData(){
        $this.Data = @{
            attrs = $this.Data
        }
    }

    [Hashtable]Get(){
        $this.Format[0] = "Getting information about"
        $Message = $this.Pattern -f $this.Format

        $arguments = @{
            APICall = $this.URI
            Payload = $this.Data
            Method  = "GET"
            Message = $Message
        }
        return Invoke-IcingaApi @arguments
    }

    [Hashtable]Register(){
        $this.SerializeData()
        $this.Format[0] = "Registering"
        $Message = $this.Pattern -f $this.Format
        $Method = "PUT"
        ## Not using this.
        #if ($this.Get()){
        #    $Method = "POST"
        #}

        $arguments = @{
            APICall = $this.URI
            Payload = $this.Data
            Method  = $Method
            Message = $Message
        }
        return Invoke-IcingaApi @arguments
    }

    [Hashtable]Remove(){
        if (-not($this.Name)){
            throw "Server name is empty!"
        }
        Write-Debug "Removing"
        Write-Debug $this.Pattern
        $this.Format[0] = "Removing"
        $Message = $this.Pattern -f $this.Format
        Write-Debug $Message

        $arguments = @{
            APICall = $this.URI
            Payload = @{}
            Method  = "Delete"
            Message = $Message
        }
        return Invoke-IcingaApi @arguments
    }
}

class IcingaHost : IcingaObject {
    [IcingaObjectType]$ObjectType = 0
    # Constructor
    IcingaHost([String]$servername, [hashtable]$data) : base($servername, $data){
        $this.URI = "objects/hosts/{0}" -f $this.Name
    }

    [Hashtable]RemoveCascade(){
        $temp = $this.URI
        $this.URI = $this.URI+"?cascade=1"
        $obj = $this.Remove()
        $this.URI = $temp
        return $obj
    }
}

class IcingaService : IcingaObject {
    [string]$ServerName
    [IcingaObjectType]$ObjectType = 1
    IcingaService([string]$servername, [string]$servicename, [hashtable]$data) : base($servicename, $data) {
        $this.ServerName = $servername
        $this.ObjectType = 1
        $this.Pattern = "{0} {1} '{2}' for server '{3}'"
        $this.Format = $this.Format + @($this.ServerName)
        $this.URI = "objects/services/{0}!{1}" -f $this.ServerName, $this.Name
    }
    [Hashtable]RemoveCascade(){
        $temp = $this.URI
        $this.URI = $this.URI+"?cascade=1"
        $obj = $this.Remove()
        $this.URI = $temp
        return $obj
    }
}

class IcingaHostGroup : IcingaObject {
    [IcingaObjectType]$ObjectType = 2
    IcingaHostGroup([string]$Name, [hashtable]$data) : base($name, $data) {
        $this.URI = "objects/hostgroups/{0}" -f $this.Name
    }
}

class IcingaContactGroup : IcingaObject {
    [IcingaObjectType]$ObjectType = 3
    IcingaContactGroup([string]$Name, [hashtable]$data) : base($name, $data) {
        $this.URI = "objects/usergroups/{0}" -f $this.Name
    }
}

class IcingaServiceGroup : IcingaObject {
    [IcingaObjectType]$ObjectType = 4    
    IcingaServiceGroup([string]$Name, [hashtable]$data) : base($name, $data){
        $this.URI = "objects/servicegroups/{0}" -f $this.Name
    }
}

class IcingaContact  : IcingaObject {
    [IcingaObjectType]$ObjectType = 5

    # In Icinga `name` is actually an email adress (UCO@muni.cz) but not for sending emails
    IcingaContact([string]$name, [hashtable]$data) : base($name, $data) {
        $this.URI = "objects/users/{0}" -f $this.Name
    }
}

class IcingaNotification : IcingaObject {
    [IcingaObjectType]$ObjectType = 6
    [string]$ServerName
    [string]$ServiceName

    IcingaNotification([string]$serverName, [string]$servicename, [string]$name, [hashtable]$data) : base($name, $data) {
        $this.ctor($serverName)
        $this.ServiceName = $servicename
        $this.URI = "objects/notifications/{0}!{1}!{2}" -f $this.ServerName, $this.ServiceName, $this.Name
        $this.Pattern = "{0} {1} '{2}' for server '{3}' and service: '{4}'"
        $this.Format = @("Action", [IcingaObjectType].GetEnumName($this.ObjectType), $this.Name, $this.ServerName, $this.ServiceName)
        $this.data.add("service_name", $this.ServiceName)
    }

    IcingaNotification([string]$serverName, [string]$name, [hashtable]$data) : base ($name, $data) {
        $this.ctor($serverName)
    }
    # Delegating contructor
    hidden ctor([string]$serverName){
        $this.ServerName = $serverName
        $this.URI = "objects/notifications/{0}!{1}" -f $this.ServerName, $this.Name
        $this.Pattern = "{0} {1} '{2}' for server '{3}'"
        $this.Format = @("Action", [IcingaObjectType].GetEnumName($this.ObjectType), $this.Name, $this.ServerName)
        $this.data.add("host_name", $this.ServerName)
    }
}

<#
.SYNOPSIS
    Get's the Icinga objects from file and returns them as a PSCustomObject.
.DESCRIPTION
    Loads configuration file and returns the json configuration
    as a PSCustomObject.
.PARAMETER ObjectType 
    Type of the object or name of the configuration file, e.g <objecttype>.json
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Get-IcingaObjects -ObjectType hosts
    Will get hosts.json content
.EXAMPLE
    Get-IcingaObjects "vault" 
#>
function Get-IcingaObjects {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param (
        [String]$ObjectType,
        [String]$Path = $IcingaObjects
    )
    return Get-Content (Join-Path $Path ($ObjectType+".json")) | ConvertFrom-Json | ConvertPSObjectToHashtable
}

<#
.SYNOPSIS
    Get's information about Host Group directly from endpoint.
.DESCRIPTION
    Get's information about Host Group directly from endpoint as a json.
.PARAMETER Name 
    Name of the Host Group
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Get-IcingaHostGroup "my-host-group"
#>
function Get-IcingaHostGroup {
    Param (
        [string]$Name
    )
    [IcingaHostGroup]$object = [IcingaHostGroup]::new($Name, @{})
    return $object.Get()
}

<#
.SYNOPSIS
    Registers the Contact object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Contact
.PARAMETER Data 
    Data for the Contact as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaContact -Name "contact-name" -Data '{"display_name":"Contact One"}'
#>
function Register-IcingaContact {
    Param (
        [string]$Name,
        [hashtable]$Data
    )
    [IcingaContact]$object = [IcingaContact]::new($Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Registers the Contact Group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Contact Group
.PARAMETER Data 
    Data for the Contact Group as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaContactGroup -Name "contactgroup-name" -Data '{"display_name":"Contact Group One"}'
#>
function Register-IcingaContactGroup {
    Param (
        [string]$Name,
        [hashtable]$Data
    )
    [IcingaContactGroup]$object = [IcingaContactGroup]::new($Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Registers the Service Group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Service Group
.PARAMETER Data 
    Data for the Service Group as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaServiceGroup -Name "servicegroup-name" -Data '{"display_name":"Service Group One"}'
#>
function Register-IcingaServiceGroup {
    Param (
        [string]$Name,
        [hashtable]$Data
    )
    [IcingaServiceGroup]$object = [IcingaServiceGroup]::new($Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Registers the Host Group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Host Group
.PARAMETER Data 
    Data for the Host Group as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaHostGroup -Name "prefix-hostgroup-name" -Data @{"display_name"="Host Group One"}
#>
function Register-IcingaHostGroup {
    Param (
        [string]$Name,
        [hashtable]$Data
    )
    [IcingaHostGroup]$object = [IcingaHostGroup]::new($Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Registers the Host object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Host
.PARAMETER Data 
    Data for the Host as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaHost -Name "servername" -Data @{"display_name"="server.."...}
#>
function Register-IcingaHost {
    Param (
        [string]$Name,
        [hashtable]$Data
    )
    [IcingaHost]$object = [IcingaHost]::new($Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Registers the Notification object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Notification
.PARAMETER ServerName 
    Name of the Host that the Notification is for.
.PARAMETER ServiceName 
    Name of the Service on the Host that the Notification is for.
.PARAMETER Type 
    Decide if the notification is for host or service.
    Possible values:
        - host - for host notification
        - service - for service notification
.PARAMETER Data 
    Data for the Notification as a hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Register-IcingaNotification -Name "notification-service-down" -ServiceName "memuse" -ServerName "hostname"
    -Data @{...} -Type "service"
.EXAMPLE
    Register-IcingaNotification -Name "notification-host-down" -ServerName "hostname"
    -Data @{...} -Type "host"
#>
function Register-IcingaNotification {
    Param (
        [string]$ServerName,
        [string]$ServiceName,
        [string]$Name,
        [hashtable]$Data,
        [ValidateSet("host", "service")]
        [string]$Type
    )
    if ($Type -eq "host"){
        [IcingaNotification]$object = [IcingaNotification]::new($ServerName, $Name, $Data)
    } else {
        [IcingaNotification]$object = [IcingaNotification]::new($ServerName, $ServiceName, $Name, $Data)
    }
    $object.Register()
}
<#
.SYNOPSIS
    Unregisters the Host group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Host Group.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaHostGroup -Name "group-name"
#>
function Unregister-IcingaHostGroup {
    Param (
        [string]$Name,
        [hashtable]$Data = @{}
    )
    [IcingaHostGroup]$object = [IcingaHostGroup]::new($Name, $Data)
    $object.Remove()
}
function Register-IcingaService {
    Param (
        [string]$Name,
        [string]$ServerName,
        [hashtable]$Data
    )
    [IcingaService]$object = [IcingaService]::new($ServerName, $Name, $Data)
    $object.Register()
}

<#
.SYNOPSIS
    Unregisters the Host object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Host.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.PARAMETER Cascade
    Use this if host notifications and services should be also removed.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaHost -Name "hostname" -Cascade
#>
function Unregister-IcingaHost {
    Param (
        [string]$Name,
        [hashtable]$Data = @{},
        [switch]$Cascade
    )
    [IcingaHost]$object = [IcingaHost]::new($Name, $Data)
    if ($Cascade){
        $object.RemoveCascade()
    } else {
        $object.Remove()
    }
}

<#
.SYNOPSIS
    Unregisters the Contact Group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the object in Icinga.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaContactGroup -Name "group-name"
#>
function Unregister-IcingaContactGroup {
    Param (
        [string]$Name,
        [hashtable]$Data = @{}
    )
    [IcingaContactGroup]$object = [IcingaContactGroup]::new($Name, $Data)
    $object.Remove()
}

<#
.SYNOPSIS
    Unregisters the Service Group object to the Icinga endpoint.
.PARAMETER Name 
    Name of the object in Icinga.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaServiceGroup -Name "service-name"
#>
function Unregister-IcingaServiceGroup {
    Param (
        [string]$Name,
        [hashtable]$Data = @{}
    )
    [IcingaServiceGroup]$object = [IcingaServiceGroup]::new($Name, $Data)
    $object.Remove()
}

<#
.SYNOPSIS
    Unregisters the Contact object to the Icinga endpoint.
.PARAMETER Name 
    Name of the object in Icinga.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaContact -Name "contact-name"
#>
function Unregister-IcingaContact {
    Param (
        [string]$Name,
        [hashtable]$Data = @{}
    )
    [IcingaContact]$object = [IcingaContact]::new($Name, $Data)
    $object.Remove()
}

<#
.SYNOPSIS
    Unregisters the Service object to the Icinga endpoint.
.PARAMETER Name 
    Name of the object in Icinga.
.PARAMETER ServerName 
    Name of the host that service is for in Icinga.
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.PARAMETER Cascade
    Use this if service notifications should be also removed.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaService -Name "contact-name" -Cascade
#>
function Unregister-IcingaService {
    Param (
        [string]$Name,
        [string]$ServerName,
        [hashtable]$Data = @{},
        [switch]$Cascade
    )
    [IcingaService]$object = [IcingaService]::new($ServerName, $Name, $Data)
    if ($Cascade){
        $object.RemoveCascade()
    } else {
        $object.Remove()
    }
}

<#
.SYNOPSIS
    Unregisters the Notification object to the Icinga endpoint.
.PARAMETER Name 
    Name of the Notification
.PARAMETER ServerName 
    Name of the Host that the Notification is for.
.PARAMETER ServiceName 
    Name of the Service on the Host that the Notification is for.
.PARAMETER Type 
    Decide if the notification is for host or service.
    Possible values:
        - host - for host notification
        - service - for service notification
.PARAMETER Data 
    Additional data. This can be empty hashtable.
.NOTES
    File Name      : pswicinga.ps1
    Author         : Adrian Rosinec (rosinec@ics.muni.cz)
.EXAMPLE
    Unregister-IcingaNotification -Name "notification-service-down" -ServiceName "memuse" -ServerName "hostname"
    -Data '{"display_name":"server.."...}' -Type "service"
#>
function Unregister-IcingaNotification {
    Param (
        [string]$ServerName,
        [string]$ServiceName,
        [string]$Name,
        [hashtable]$Data,
        [ValidateSet("host", "service")]
        [string]$Type
    )
    if ($Type -eq "host"){
        [IcingaNotification]$object = [IcingaNotification]::new($ServerName, $Name, $Data)
    } else {
        [IcingaNotification]$object = [IcingaNotification]::new($ServerName, $ServiceName, $Name, $Data)
    }
    $object.Remove()
}

function Invoke-IcingaApi {
    Param(
        $APICall,
        $Payload,
        $Method = "PUT",
        $Message = ""
    )

    Get-TypeData -TypeName System.Array | Remove-TypeData
    $body = (ConvertTo-Json -Depth 10 $Payload)

    $output = @{}
    if (-not($endpoint)){
        throw "Missing endpoint, nowhere to call requests."
    }

    if ($Global:IcingaTestOnly){
        Write-Nice $Message "TEST"
        return
    }

    Write-debug $endpoint
    $timeout = 3
    while ($timeout -gt 0) {
        try {
            $output = $endpoint.Call($APICall, $Method, $body)
            Write-Nice -Message $Message -Short "OK" -Info $timeout
            $timeout = 0
        } catch {
            if ($timeout -eq 1) {
                Write-Debug "----------------------------------------------"
                Write-Nice -Message $Message -Short "Failed" -Info $timeout
                Write-Debug $_
                $output = @{}
            }
        }  
        $timeout = $timeout - 1
    }
    return $output
}

function Write-Nice {
    Param (
        $Message,
        $Short = "OK",
        $Color = "White",
        $Info = ""
    )
    switch ($Short) {
        "ok" { $Color = "DarkGreen"; break}
        "failed" { $Color = "red"; break}
        Default {break}
    }
    if($Info){
        $info = " ({0}) " -f $Info
    } else {
        $info = " "
    }
    Write-Host "[" -NoNewline
    Write-Host " $Short " -NoNewline -ForegroundColor $Color
    Write-Host "]$info$Message"
}
function Get-IcingaObjectsFromVars {
    Param (
        [hashtable]$Object,
        [string]$ObjectType,
        [string]$ObjectTypeSets
    )
    $objects = $Object["vars"][$ObjectType]
    if (-not($objects)){
        $objects = @()
    }
    if ($object["vars"][$ObjectTypeSets]){
        $object["vars"][$ObjectTypeSets] | ForEach-Object {
            if ($IcingaCurrentObjects[$ObjectTypeSets][$_]){
                $objects += $IcingaCurrentObjects[$ObjectTypeSets][$_]
            }
        }
    }

    return $objects
}

function ConvertPSObjectToHashtable {
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process {
        if ($null -eq $InputObject) { 
            return $null 
        }
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string] -and $InputObject -isnot [hashtable]){
            $collection = @(
                foreach ($object in $InputObject) { 
                    ConvertPSObjectToHashtable $object 
                }
            )
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]){
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties){
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }
            return $hash
        } else {
            return $InputObject
        }
    }
}
