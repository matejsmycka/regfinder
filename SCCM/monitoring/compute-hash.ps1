$json = @{}
$servers_path = Join-Path $PWD "servers"
$servers = Get-ChildItem $servers_path | Where-Object {$_.Attributes -eq "Directory"}
foreach ($server in $servers) {
    $path = Join-Path $servers_path $server.name
    
    $script_path = Join-Path $path "scripts"
    if (Test-Path $script_path){
        $scripts = Get-ChildItem $script_path -Recurse -File | ForEach-Object {$_.Fullname -replace ".*scripts\\" -replace "\\","/"}
    } else {
        $scripts = @()
    }

    $service_path = Join-Path $path "services"
    if (Test-Path $service_path){
        $services = Get-ChildItem $service_path -Recurse -File | ForEach-Object {$_.Fullname -replace ".*services\\" -replace "\\","/"}
    } else {
        $services = @()
    }
    
    $includes = @{}
    foreach ($child in (Get-ChildItem $path | Where-Object name -like *.ini | Select-Object -ExpandProperty name)){
        $includes.Add($child, (Get-FileHash -Path (Join-Path $path $child) -Algorithm MD5).hash)
    }

    $value = @{
        "includes"  = $includes
        "scripts"   = $scripts
        "services"  = $services
    }

    $json.Add($server.name, $value)
}
ConvertTo-Json $json | Out-File versions.json -Encoding "ascii"