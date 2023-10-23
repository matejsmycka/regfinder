# check if new version si available
$nsclient_folder = 'C:\Program Files\NSClient++\'
$work_url = "https://sccm-01.ucn.muni.cz/monitoring"

$ErrorActionPreference = "Continue"

$version_file = Invoke-WebRequest "$work_url/versions.json" -UseBasicParsing | Select-Object -exp content | ConvertFrom-Json

# script part

$default_server = $version_file.default
$current_server_name = $ENV:COMPUTERNAME
$current_server = $version_file.$current_server_name

# copy scripts

$nsclient_folder_scripts = Join-Path $nsclient_folder "scripts"
if (-not(Test-Path $nsclient_folder_scripts)) {
    New-Item -Type Directory -Path $nsclient_folder_scripts
}
foreach ($script in $default_server.scripts){
    $name = $script -replace "default/"
    $path = join-path $nsclient_folder_scripts $name
    $folder = Split-Path $path -Parent
    if (-not(Test-Path $folder)) {
        New-Item -Type Directory -Path $folder
    }
    $url = "$work_url/servers/default/scripts/$script"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path
}

foreach ($script in $current_server.scripts){
    $name = $script -replace "$($current_server_name)/"
    $path = join-path $nsclient_folder_scripts $name
    $folder = Split-Path $path -Parent
    if (-not(Test-Path $folder)) {
        New-Item -Type Directory -Path $folder
    }
    $url = "$work_url/servers/$current_server_name/scripts/$script"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path
}

# copy services

$nsclient_folder_services = Join-Path $nsclient_folder "services"
if (-not(Test-Path $nsclient_folder_services)) {
    New-Item -Type Directory -Path $nsclient_folder_services
}
foreach ($service in $default_server.services){
    $name = $service -replace "default/"
    $path = join-path $nsclient_folder_services $name
    $folder = Split-Path $path -Parent
    if (-not(Test-Path $folder)) {
        New-Item -Type Directory -Path $folder
    }
    $url = "$work_url/servers/default/services/$service"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path
}
foreach ($service in $current_server.services){
    $name = $service -replace "$($current_server)/"
    $path = join-path $nsclient_folder_services $name
    $folder = Split-Path $path -Parent
    if (-not(Test-Path $folder)) {
        New-Item -Type Directory -Path $folder
    }
    $url = "$work_url/servers/$current_server_name/services/$service"
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $path
}

# config part

$includes = $current_server.includes
if (-not($includes)){
    #Fallback to default includes
    $includes = $default_server.includes
}

foreach ($ini in $includes | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name){
    $name = Split-path $ini -Leaf
    $url = "$work_url/servers/default/$name"
    if ($current_server){
        $url = "$work_url/servers/$ENV:COMPUTERNAME/$name"
    }
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (join-path $nsclient_folder $name)
}

Stop-Service -Name "nscp" -Force
Start-Service -Name "nscp"