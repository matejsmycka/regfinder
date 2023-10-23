$key = 'NW6C2-QMPVW-D7KKK-3GKT6-VCFB2'

Write-Host 'Probiha pridani KMS serveru.' -ForegroundColor Green
c:\windows\system32\cscript.exe c:\windows\system32\slmgr.vbs /skms kms.ics.muni.cz 

Write-Host 'Probiha povyseni verze Windows na Education, pocitact muze byt restartovan.' -ForegroundColor Green
c:\windows\system32\changepk.exe /ProductKey $key

Start-Sleep -s 5