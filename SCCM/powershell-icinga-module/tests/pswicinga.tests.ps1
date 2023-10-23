. .\pswicinga.ps1

$Global:IcingaObjects = "$(Get-Location)\tests\configurations\"
$Global:endpoint = $null

Describe 'Getting configuration files' {

    It "Json to hashtable" {
        $vault = Get-IcingaObjects -ObjectType vault
        $vault | Should -Not -BeNullOrEmpty
        $vault | Should -BeOfType Hashtable
    }
}


Describe 'API Class' {

    Context "Testing credentials" {
        It "Credentials from vault.json file" {
            $endpoint = [IcingaApi]::new("vault")
            $endpoint.creds | Should -Not -BeNullOrEmpty
            $endpoint.creds.username | Should -Be "username"
            $endpoint.creds.password | Should -BeOfType "System.Security.SecureString"
        }
    }
    Context "Testing instance" {
        It "Instance custom endpoint" {
            $endpoint = [IcingaApi]::new("vault", "serverxy")
            $endpoint.Instance | Should -Not -BeNullOrEmpty
            $endpoint.Instance | Should -Be "serverxy"
            $endpoint.GetIcingaInstanceURL() | Should -Be "https://serverxy.cz:5665/v1/"
        }
    }

    It "Testing no credentials" {
        Mock Get-Credential {
            $pw = ConvertTo-SecureString "empty" -AsPlainText -Force
            $creds = New-Object System.Management.Automation.PSCredential("testing", $pw)
            $creds
        }
        $endpoint = [IcingaApi]::new("vault-empty")
        $endpoint.creds.username | Should -Be "testing"
        $endpoint.creds.password | Should -BeOfType "System.Security.SecureString"
    }
    It "Testing empty credentials" {
        Mock Get-Credential {return}
        {[IcingaApi]::new("vault-empty")} | Should -Throw "No credentials entered"
    }
}

Describe 'Registering Objects' {
    Mock Invoke-RestMethod {
        return @{ data = $args }
    }  
    $endpoint = $null
    $endpoint = [IcingaApi]::new("vault", "serverxy")

    Context "Registering Hosts" {
        $objs = Get-IcingaObjects -ObjectType "hosts"

        It "Host with empty name" {
            {[IcingaHost]::new("", @{host="uvt"})} | Should -Throw
        }
        It "Host with empty data" {
            {[IcingaHost]::new("uvt", @{})} | Should -Throw
        }
        It "API call url is valid for host: <ObjectName>" -TestCases @(
            @{ ObjectName = 'uvt-server.munics.cz'; Expected = 'objects/hosts/uvt-server.munics.cz' }
            @{ ObjectName = 'uvt-cloud.munics.cz'  ; Expected = 'objects/hosts/uvt-cloud.munics.cz' }
          ) {
            param ($ObjectName, $Expected)
      
            $obj = [IcingaHost]::new($ObjectName, $objs[$ObjectName])
            $obj.URI | Should -Be $Expected
            $obj.name | Should -Be $ObjectName
        }

        Context "Sending data to Icinga endpoint" {
            $obj = [IcingaHost]::new("uvt-server.munics.cz", $objs["uvt-server.munics.cz"])
            $registration = $obj.Register().status.data

            It "has valid parameter <NiceName>" -TestCases @(
                @{NiceName = "URI"; Parameter = "-Uri:"; Expected = "https://serverxy.cz:5665/v1/objects/hosts/uvt-server.munics.cz"},
                @{NiceName = "ContentType"; Parameter = "-ContentType:"; Expected = "application/json"},
                @{NiceName = "Method"; Parameter = "-Method:"; Expected = "PUT"},
                @{NiceName = "Credential"; Parameter = "-Credential:"; Expected = $endpoint.creds}
                @{NiceName = "Body"; Parameter = "-Body:"; Expected = ConvertTo-Json -Depth 4 $obj.Data}
            ) {
                Param ($Parameter, $Expected)
                $registration | Should -Contain $Parameter
                $registration | Should -Contain $Expected
            }
        }
    }

    Context "Registering Host Groups" {
        It "HostGroup with empty name" {
            { [IcingaHostGroup]::new("", @{display_name = "Test Group"}) }| Should -Throw
        }
        It "HostGroup with empty data" {
            { [IcingaHostGroup]::new("test-group", @{}) }| Should -Throw
        }
        It "Valid API Url" {
            $obj = [IcingaHostGroup]::new("test-group", @{display_name = "Test Group"})
            $obj.URI | Should -Be "objects/hostgroups/test-group"
        }
        Context "Sending data to Icinga endpoint" {
            $obj = [IcingaHostGroup]::new("test-group", @{display_name = "Test Group"})
            $registration = $obj.Register().status.data

            It "has valid parameter <NiceName>" -TestCases @(
                @{NiceName = "URI"; Parameter = "-Uri:"; Expected = "https://serverxy.cz:5665/v1/objects/hostgroups/test-group"},
                @{NiceName = "ContentType"; Parameter = "-ContentType:"; Expected = "application/json"},
                @{NiceName = "Method"; Parameter = "-Method:"; Expected = "PUT"},
                @{NiceName = "Credential"; Parameter = "-Credential:"; Expected = $endpoint.creds}
                @{NiceName = "Body"; Parameter = "-Body:"; Expected = ConvertTo-Json -Depth 4 $obj.Data}
            ) {
                Param ($Parameter, $Expected)
                $registration | Should -Contain $Parameter
                $registration | Should -Contain $Expected
            }
        }
    }

    Context "Registering Notifications" {
        $objs = Get-IcingaObjects -ObjectType "notifications"
        
        Context "Host Notifications" {
            It "API call url is valid for Host Notification: <ObjectName>" -TestCases @(
                @{ ObjectName = 'default-notification-for-host'; Expected = 'objects/notifications/uvt-server!default-notification-for-host' }) {
                param ($ObjectName, $Expected)
          
                $obj = [IcingaNotification]::new("uvt-server", $ObjectName, $objs[$ObjectName].Clone())
                $obj.URI | Should -Be $Expected
                $obj.ServerName | Should -Be "uvt-server"
                $obj.name | Should -Be $ObjectName
            }
            It "Valid server name parameter" {
            $obj = [IcingaNotification]::new("uvt-server", "default-notification-for-host", $objs["default-notification-for-host"].Clone())
            $obj.Data["host_name"] | Should -Be "uvt-server"
            }
            Context "Sending data to Icinga endpoint" {
            $obj = [IcingaNotification]::new("uvt-server", "default-notification-for-host", $objs["default-notification-for-host"].Clone())
            $registration = $obj.Register().status.data

                It "has valid parameter <NiceName>" -TestCases @(
                    @{NiceName = "URI"; Parameter = "-Uri:"; Expected = "https://serverxy.cz:5665/v1/objects/notifications/uvt-server!default-notification-for-host"},
                    @{NiceName = "ContentType"; Parameter = "-ContentType:"; Expected = "application/json"},
                    @{NiceName = "Method"; Parameter = "-Method:"; Expected = "PUT"},
                    @{NiceName = "Credential"; Parameter = "-Credential:"; Expected = $endpoint.creds}
                    @{NiceName = "Body"; Parameter = "-Body:"; Expected = ConvertTo-Json -Depth 4 $obj.Data}
                ) {
                    #Invoke-RestMethod -Uri $URI -ContentType "application/json" -Method $Method -Credential $this.creds -Headers $header -Body $body
                    Param ($Parameter, $Expected)
                    $registration | Should -Contain $Parameter
                    $registration | Should -Contain $Expected
                }
            }
        }

        Context "Host Service Notifications" {
            It "API call url is valid for Host Service Notification: <ObjectName>" -TestCases @(
                @{ ObjectName = 'default-notification-for-service'; Expected = 'objects/notifications/uvt-server!ping-service!default-notification-for-service' }
              ) {
                param ($ObjectName, $Expected)
          
                $obj = [IcingaNotification]::new("uvt-server", "ping-service", $ObjectName, $objs[$ObjectName].Clone())
                $obj.URI | Should -Be $Expected
                $obj.ServerName | Should -Be "uvt-server"
                $obj.ServiceName | Should -Be "ping-service"
                $obj.name | Should -Be $ObjectName
              }

            It "Valid server name parameter" {
            $obj = [IcingaNotification]::new("uvt-server", "default-notification-for-service", $objs["default-notification-for-service"].Clone())
            $obj.ServerName = "uvt-server"
            $obj.Data["host_name"] | Should -Be "uvt-server"
            }

            It "Valid service name parameter" {
            $obj = [IcingaNotification]::new("uvt-server", "ping-service", "default-notification-for-service", $objs["default-notification-for-service"].Clone())
            $obj.ServiceName = "ping-service"                
            $obj.Data["service_name"] | Should -Be "ping-service"
            }
            Context "Sending data to Icinga endpoint" {
                $obj = [IcingaNotification]::new("uvt-server", "ping-service", "default-notification-for-host", $objs["default-notification-for-host"].Clone())
                $registration = $obj.Register().status.data
    
                It "has valid parameter <NiceName>" -TestCases @(
                    @{NiceName = "URI"; Parameter = "-Uri:"; Expected = "https://serverxy.cz:5665/v1/objects/notifications/uvt-server!ping-service!default-notification-for-host"},
                    @{NiceName = "ContentType"; Parameter = "-ContentType:"; Expected = "application/json"},
                    @{NiceName = "Method"; Parameter = "-Method:"; Expected = "PUT"},
                    @{NiceName = "Credential"; Parameter = "-Credential:"; Expected = $endpoint.creds}
                    @{NiceName = "Body"; Parameter = "-Body:"; Expected = ConvertTo-Json -Depth 4 $obj.Data}
                ) {
                    #Invoke-RestMethod -Uri $URI -ContentType "application/json" -Method $Method -Credential $this.creds -Headers $header -Body $body
                    Param ($Parameter, $Expected)
                    $registration | Should -Contain $Parameter
                    $registration | Should -Contain $Expected
                }
            }
        }
    }
}

Describe 'Getting Objects' {
    Mock Invoke-RestMethod {
        return @{ data = $args }
    }
    $endpoint = $null
    $endpoint = [IcingaApi]::new("vault", "serverxy")
    
    Context "Getting Hosts" {
        $objs = Get-IcingaObjects -ObjectType "hosts"
        Context "Getting data from Icinga endpoint" {
            $endpoint = $null
            $endpoint = [IcingaApi]::new("vault", "serverxy")
            $obj = [IcingaHost]::new("uvt-server", $objs["uvt-server.munics.cz"])
            $registration = $obj.Get().status.data

            It "has valid parameter <NiceName>" -TestCases @(
                @{NiceName = "URI"; Parameter = "-Uri:"; Expected = "https://serverxy.cz:5665/v1/objects/hosts/uvt-server"},
                @{NiceName = "ContentType"; Parameter = "-ContentType:"; Expected = "application/json"},
                @{NiceName = "Credential"; Parameter = "-Credential:"; Expected = $endpoint.creds}
            ) {
                Param ($Parameter, $Expected)
                $registration | Should -Contain $Parameter
                $registration | Should -Contain $Expected
            }

            It "should not contain body parameter" {
                $registration | Should -not -Contain "-Body:"
            }
        }
    }
}

Describe 'Deleting Objects' {
    Mock Invoke-RestMethod {
        return @{ data = $args }
    }
    $endpoint = $null
    $endpoint = [IcingaApi]::new("vault", "serverxy")

    $objs = Get-IcingaObjects -ObjectType "hosts"
    $obj = [IcingaHost]::new("uvt-server", $objs["uvt-server.munics.cz"])
    $a = $obj.Remove().status.data

    It "Deleting host URI" {
        $a | Should -Contain "-Uri:"
        $a | Should -Contain "https://serverxy.cz:5665/v1/objects/hosts/uvt-server"
        $a | Should -Contain "Delete"
    }
}