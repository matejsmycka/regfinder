$config = Import-Clixml 'C:\Windows\Temp\addtostaff.xml'
$credential = Get-Credential -credential $config.account

try {      
        Write-Host "Probiha pridani pocitace do domeny, pote bude nasledovat restart"  -ForegroundColor Green
        Add-Computer -DomainName $config.domain -Credential $credential -OUPath $config.OUPath -Restart -ErrorAction Stop 
}
catch {
    Write-Host "Pridani do domeny se nezdarilo: " -ForegroundColor Red
    $_
}

Start-Sleep -s 5