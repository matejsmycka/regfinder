$config = Import-Csv -Path "$PSScriptRoot\Config\configuration.csv" -Delimiter ';'
$selected  = $config | Out-GridView -OutputMode single -Title "Vyberte pracoviste:"

#Ulozeni vyberu do docasneho souboru
$selected | Export-CliXML 'C:\Windows\Temp\addtostaff.xml'

try {
    Write-Host "Zadajte jmeno uzivatele (max 8 znaku), pouzije se jako nazev PC: " -ForegroundColor Green -NoNewline
    $name = Read-Host
    if ($name.Length -eq 0) {
        Write-Host "Uzivatelske jmeno nebylo zadane"  -ForegroundColor Red
    } 
    else {
        if ($name.Length -gt 8){
            Write-Host "Uzivatelske jmeno je delsi nez 8 znaku a bylo zkraceno." -ForegroundColor Red
            $name=$name.Substring(0,8)
        }
        try {
            $NewComputerName = $selected.prefix + $name.ToUpper() + "-NB"
            Rename-Computer -NewName $NewComputerName -Force -ErrorAction Stop
            Write-Host "Prejmenovani pocitace probehlo bez problemnu, pocitac bude restartovan za 10 vterin."  -ForegroundColor Green
            Start-Sleep -s 10
            Restart-Computer
            }
        catch {
            Write-Host "Prejmenovani se nepovedlo: " -ForegroundColor Red
            $_
            Start-Sleep -s 5
        }
    }
}
catch {
    Write-Host "Prejmenovani se nepovedlo: " -ForegroundColor Red
    $_
    Start-Sleep -s 5
}