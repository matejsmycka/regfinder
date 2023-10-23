$computer = "testovatko3.staff.ucn.muni.cz"
$computerr = "testovatko3.staff.ucn.muni.c"

$firstPingTest = $false
$lastPingTest = $false
$firstStopComputer = $false
$secondStopComputer = $false


"PRVOTNE TESTOVANIE SPOJENIA (PING)..."
try{
    Test-Connection -ComputerName $computer -Count 4 -ErrorAction stop
    $firstPingTest = $true
    "PRVOTNE TESTOVANIE SPOJENIA (PING)... OK"
}
catch{
    $firstPingTest = $false 
    "PRVOTNE TESTOVANIE SPOJENIA (PING)... PING NEODPOVEDA"   
}

"PRVOTNE ZASLANIE PRIKAZU SHUTDOWN..."
try{
    Stop-Computer -Force -ComputerName $computer -ErrorAction stop
    $firstStopComputer = $true
    "PRVOTNE ZASLANIE PRIKAZU SHUTDOWN... OK"
}
    catch{
    $firstStopComputer = $false
    $_.Exception
    "PRVOTNE ZASLANIE PRIKAZU SHUTDOWN... ERROR"
}


if($firstPingTest -eq $false){
    "DRUHOTNE ZASLANIE PRIKAZU SHUTDOWN..."
    Start-Sleep -Seconds 10 
    try{
        Stop-Computer -Force -ComputerName $computer -ErrorAction stop
        $secondStopComputer = $true
        "DRUHOTNE ZASLANIE PRIKAZU SHUTDOWN... OK"
    }
    catch{
        $secondStopComputer = $false
        $_.Exception
        "DRUHOTNE ZASLANIE PRIKAZU SHUTDOWN... ERROR"
    }   
}

"KONCOVE TESTOVANIE SPOJENIA (PING)..."
$lastPingTest = $true
$i=1
while(($lastPingTest -eq $true) -AND ($i -lt 60)){
    try{
        Test-Connection -ComputerName $computer -Count 4 -ErrorAction stop
        $lastPingTest = $true
        "KONCOVE TESTOVANIE SPOJENIA (PING)... ZAPNUTY  -  pokus ($i)"
    }
    catch{
        $lastPingTest = $false  
        "KONCOVE TESTOVANIE SPOJENIA (PING)... VYPNUTY - pokus ($i)"  
    }
    $i++
}

"FINALNE VYHODNOTENIE..."
if($lastPingTest -eq $false){
    $shutdownResult = $true
    "FINALNE VYHODNOTENIE... PODARILO SA VYPNUT"
}else{
    $shutdownResult =$false
    "FINALNE VYHODNOTENIE... NEPODARILO SA VYPNUT"
}

$shutdownResult

    

