Param(
	[Parameter(Mandatory = $True, Position = 1)]
	[string]$operationType
)


#includes script with functions because of paralel processing via start-job
."C:\pcsm_backend\TestEnvironment\functions_include.ps1"



function mailCPS{
     param (
		    [Parameter(Mandatory = $False, Position = 1)]
		    [string]$mailTo,
		    [Parameter(Mandatory = $True, Position = 2)]
		    [string]$dateFrom,
		    [Parameter(Mandatory = $True, Position = 3)]
		    [string]$dateTo,
            [Parameter(Mandatory = $True, Position = 4)]
		    [string]$operacia,
            [Parameter(Mandatory = $False, Position = 5)]
		    [string]$poznamka,
            [Parameter(Mandatory = $True, Position = 6)]
		    [string]$lokalitaName,
            [Parameter(Mandatory = $True, Position = 7)]
		    [string]$frontaID
	 )  
	

        [string]$log=""



	

        $info = New-Object System.Data.DataSet
	    $info = mysqlQuerySelect -query "SELECT * FROM logs WHERE id_fronta='$frontaID' AND first_check>='$dateFrom' AND last_check<='$dateTo' AND process='scheduler' ORDER BY computer_name"
	    $dataTable = new-object System.Data.DataTable
	    $dataTable = $info.Tables[0] 
        
        $highPriority=$false

        $dataTable | foreach{
            $computerName = $_.computer_name  
            $computer_status = $_.status  
                if($computer_status -eq "FAILED"){
                    $log += "$computerName - <font style='color:#ff0000'>$computer_status</font><br>"
                    $highPriority = $True
                }else{
                    $log += "$computerName - <font style='color:#00b400'>$computer_status</font><br>"
                }
        }      
    
    $mailTo = "oss@ics.muni.cz,"+$mailTo
    $mailTotext = $mailTo.Replace(",",", ")

    $mailText= "<html>
                    <body style='font-size:12px;'>
                        Lokalita: <b>$lokalitaName</b>   <br>
                        Typ operácie: <b>$operacia $poznamka</b>  <br> <br>
                        Spustenie operácie: <b>$dateFrom  </b>  <br>
                        Koniec operácie: <b>$dateTo</b>  <br> 
                        Emaily: <b>$mailToText</b> <br> <br>


                        Log z operácie je dostupný v aplikácii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b>  <br><br> 

                        <b>Log strojov:</b><br><br> 
                        $log
                        <br>

                        Tento email je automaticky generovaný aplikáciou PCSM.
                    </body>
                </html>"


    #MAIL to CPSADM
    $mailPriority = "normal"
    if($highPriority -eq $true){
        $mailPriority = "high"
    }else{
        $mailPriority = "normal"
    }

    $mailTo.split(',') | foreach{
        try{
            send-mailmessage -from "PCSM <pcsm@ics.muni.cz>" -to "<$_>" -subject "PCSM - $lokalitaName - $operacia $poznamka" -BodyAsHtml -body $mailText -priority $mailPriority -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8" -ErrorAction stop
            Logger -type "INFO" -text "EMAIL odoslany na `"$_`""
        }
        catch{
            Logger -type "ERROR" -text "Nepodarilo sa odoslat email na adresu `"$_`""
            #send-mailmessage -from "PCSM <pcsm@ics.muni.cz>" -to "<oss@ics.muni.cz>" -subject "PCSM - Nespravny format emailu! "  -body "Nespravny format emailu pre task id $frontaID. Emaily niesu odosielane!" -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
        }
    }
}	

	



<#
.SYNOPSIS
Remotely Shutdown PCs.

.DESCRIPTION
Remotely shutdown PCs. Remotely shutdowns PCs and check if computer is in down state in specified time limit.
After remote shutdown check via ping if computer is down.
Logs result into pcsm database.

.PARAMETER lokalita
ID locality

.PARAMETER computerNames
FQDN names of computers

.PARAMETER author
UCN name of author account

.PARAMETER function
Name of function in case of scheduler
#>
function ShutdownPCs
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$lokalita,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$computerNames,
		[Parameter(Mandatory = $True, Position = 3)]
		[string]$author,
		[Parameter(Mandatory = $false, Position = 4)]
		[string]$function,
        [Parameter(Mandatory = $true, Position = 5)]
		[string]$frontaID,
        [Parameter(Mandatory = $false, Position = 6)]
		[string]$delay
	)
	if ($function -eq "")
	{
		$function = "vypinanie"
	}
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $author, $function, $frontaID, $delay) -ScriptBlock {
			
			."C:\pcsm_backend\testenvironment\functions_include.ps1"
			$computer = $args[0]
			$author = $args[1]
			$function = $args[2]
            $frontaID = $args[3]
			$delay = $args[4]
 
			$first_check = Get-Date -format u
			
			[bool]$stav = $true
			
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

            "KONTROLA PARAMETRU DELAY..."
            if($delay -match "delay"){
                "Odoslanie MSG 15 MIN..."
                $shutdownTime = (get-date).addMinutes(15)
                Invoke-Command -ComputerName $computer -ArgumentList $shutdownTime -command {msg.exe * /server localhost /time:5400 "Auto shutdown of this PC will be forced in 15 minutes ($($args[0])), please log off!"}
                Start-Sleep -Seconds 5400

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
            while(($lastPingTest -eq $true) -AND ($i -lt $shutDownPingNumber)){
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
                $stav = $true
                "FINALNE VYHODNOTENIE... PODARILO SA VYPNUT"
            }else{
                $stav =$false
                "FINALNE VYHODNOTENIE... NEPODARILO SA VYPNUT"
            }

		

			
			$last_check = Get-Date -format u
			if ($stav -eq $false)
			{
				Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo vypnut..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Vypnutie neprebehlo vo vyhradenom casovom limite', '', '$author', '$frontaID' )"
			}
			else
			{
				Logger -type "INFO" -text "Pocitac $computer je vypnuty..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Vypnutie prebehlo vo vyhradenom casovom limite', '', '$author', '$frontaID' )"
			}
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\shutdown_" + $_.Name + "_" + $frontaID + ".txt"
	    Receive-Job -Name $_.Name *>> $jobFilename
    }
}



<#
.SYNOPSIS
DHCP manager

.DESCRIPTION
Change DHCP reservations
Logs result into pcsm database.

#>

function dhcp(){

    param (
		    [Parameter(Mandatory = $True, Position = 1)]
		    [string]$lokalita,
		    [Parameter(Mandatory = $True, Position = 2)]
		    [string]$ClientIPAddress,
		    [Parameter(Mandatory = $True, Position = 3)]
		    [string]$author,
		    [Parameter(Mandatory = $false, Position = 4)]
		    [string]$function,
            [Parameter(Mandatory = $true, Position = 5)]
		    [string]$frontaID,
            [Parameter(Mandatory = $true, Position = 6)]
		    [string]$mac,
            [Parameter(Mandatory = $true, Position = 7)]
		    [string]$action
	    )
	    if ($function -eq "")
	    {
		    $function = "dhcp"
	    }   


    # Find out SHCP scopeID
      
    $IPaddressScope = $lokalita
    $DHCPserver = ""
    $DHCPscopeMask = ""
    $DHCPAvailableServers = @("staff-server1.staff.ucn.muni.cz", "staff-server2.staff.ucn.muni.cz", "ups-server1.ups.ucn.muni.cz", "ups-server2.staff.ucn.muni.cz", "zam-server1.zam.ucn.muni.cz", "zam-server2.zam.ucn.muni.cz")
   
    $DHCPAvailableServers | foreach {
        $dhcpServerName = $_
        Get-DhcpServerv4Scope -ComputerName $_ -ErrorAction stop | foreach {
            if($_.ScopeId -eq $IPaddressScope){       
                $DHCPserver = $dhcpServerName
                $DHCPscopeMask = $_.SubnetMask
            }                        
        }
    }



    function Get-BroadcastAddress {
        param (
            [IpAddress]$ip,
            [IpAddress]$Mask
        )
 
        $IpAddressBytes = $ip.GetAddressBytes()
        $SubnetMaskBytes = $Mask.GetAddressBytes()
 
        if ($IpAddressBytes.Length -ne $SubnetMaskBytes.Length) {
            throw "Lengths of IP address and subnet mask do not match."
            exit 0
        }
 
        $BroadcastAddress = @()
 
        for ($i=0;$i -le 3;$i++) {
            $a = $subnetMaskBytes[$i] -bxor 255
            if ($a -eq 0) {
                $BroadcastAddress += $ipAddressBytes[$i]
            }
            else {
                $BroadcastAddress += $a
            }
        }
 
        $BroadcastAddressString = $BroadcastAddress -Join "."
        return [IpAddress]$BroadcastAddressString
    }
 
    function Get-NetwotkAddress {
        param (
            [IpAddress]$ip,
            [IpAddress]$Mask
        )
 
        $IpAddressBytes = $ip.GetAddressBytes()
        $SubnetMaskBytes = $Mask.GetAddressBytes()
 
        if ($IpAddressBytes.Length -ne $SubnetMaskBytes.Length) {
            throw "Lengths of IP address and subnet mask do not match."
            exit 0
        }
 
        $BroadcastAddress = @()
 
        for ($i=0;$i -le 3;$i++) {
            $BroadcastAddress += $ipAddressBytes[$i]-band $subnetMaskBytes[$i]
 
        }
 
        $BroadcastAddressString = $BroadcastAddress -Join "."
        return [IpAddress]$BroadcastAddressString
    }
 
    function Test-IsInSameSubnet {
        param (
            [IpAddress]$ip1,
            [IpAddress]$ip2,
            [IpAddress]$mask
        )
 
        $Network1 = Get-NetwotkAddress -ip $ip1 -mask $mask
        $Network2 = Get-NetwotkAddress -ip $ip2 -mask $mask
 
        return $Network1.Equals($Network2)
    }

    

    $global:output = ""
    $mac = $mac -replace ":",""

    # Change existing reservation by IP

    function changeMACbyIP(){
        if(Test-IsInSameSubnet -ip1 $IPaddressScope -ip2 $ClientIPAddress -mask $DHCPscopeMask ){
            if($data = Get-DhcpServerv4Reservation -ComputerName $DHCPserver -IPAddress $ClientIPAddress){
                try{
                    Set-DhcpServerv4Reservation -ComputerName $DHCPserver -IPAddress $ClientIPAddress -ClientId $mac -ErrorAction SilentlyContinue
                    $global:output += "MAC adresa pre IP: $ClientIPAddress bola uspesne zmenena`n"
                }
                catch{
                    $global:output += "Chybove hlasenie: DHCP server nespracoval poziadavok pre IP $ClientIPAddress`n"
                    $global:output += ";" + $_.exception
                }
            }else{
                $global:output += "Chybove hlasenie: IP $ClientIPAddress neexistuje`n"
            }
        }else{
            $global:output += "Chybove hlasenie: Zadana IP: $ClientIPAddress nespada do vybraneho rozsahu`n"
        }
        
    }

    # Create new reservation

    function NewDHCPip(){
        if(Test-IsInSameSubnet -ip1 $IPaddressScope -ip2 $ClientIPAddress -mask $DHCPscopeMask ){
            if($data = Get-DhcpServerv4Reservation -ComputerName $DHCPserver -IPAddress $ClientIPAddress){
                $global:output += "Chybove hlasenie: Rezervacia s IP: $ClientIPAddress uz existuje `n"
            }else{
                try{
                    Add-DhcpServerv4Reservation -ComputerName $DHCPserver -ScopeId $IPaddressScope -IPAddress $ClientIPAddress -ClientId $mac -Name "PCSM-$($frontaID)-created-$(get-date -Format "yyyy-MM-dd-hh-mm-ss")" -ErrorAction SilentlyContinue
                    $global:output += "Rezervacia pre IP $ClientIPAddress s MAC $mac bola uspesne vytvorena `n"
                }
                catch{
                    $global:output += "Chybove hlasenie: DHCP server nespracoval poziadavok pre IP $ClientIPAddress`n"
                    $global:output += ";" + $_.exception
                }
            }
        }else{
            $global:output += "Chybove hlasenie: Zadana IP: $ClientIPAddress nespada do vybraneho rozsahu`n"
        }
        
    }


    # Remove existing reservation

    function removeIP(){
        if(Test-IsInSameSubnet -ip1 $IPaddressScope -ip2 $ClientIPAddress -mask $DHCPscopeMask ){
            if($data = Get-DhcpServerv4Reservation -ComputerName $DHCPserver -IPAddress $ClientIPAddress){
                try{
                    Remove-DhcpServerv4Reservation -ComputerName $DHCPserver -IPAddress $ClientIPAddress -ErrorAction SilentlyContinue
                    Remove-DhcpServerv4Lease -ComputerName $DHCPserver -IPAddress $ClientIPAddress -ErrorAction SilentlyContinue                 
                    $global:output += "Rezervacia s IP: $ClientIPAddress bola odstranena`n"
                }
                catch{
                    $global:output += "Chybove hlasenie: DHCP server nespracoval poziadavok pre IP $ClientIPAddress`n"
                    $global:output += ";" + $_.exception
                }
            }else{
                $global:output += "Chybove hlasenie: IP $ClientIPAddress neexistuje`n"
            }
        }else{
            $global:output += "Chybove hlasenie: Zadana IP: $ClientIPAddress nespada do vybraneho rozsahu`n"
        }
    }

    # Show scope reservations

    function showScopeReservations(){
        $tmp = ";"
        try{
            Get-DhcpServerv4Reservation -ComputerName $DHCPserver -ScopeId $IPaddressScope -ErrorAction SilentlyContinue | foreach {
            
                $tmp += $_.IPAddress.IPAddressToString+"|"+$_.ClientId+"|"+$_.Name+","
            
            }
                          
            $global:output += "Zoznam rezervacii pre siet $IPaddressScope bol uspesne nacitany`n" + $tmp
        }
        catch{
            $global:output += "Chybove hlasenie: DHCP server nespracoval poziadavok pre siet $IPaddressScope`n"
            $global:output += ";" + $_.exception
        }
    }

    # Action Switch

    switch ($action) {
	"NewIP" {
		NewDHCPip
	}
	"MACbyIP" {
		changeMACbyIP
	}
	"RemoveIP" {
		removeIP
	}
    "ShowScopeReservations" {
		showScopeReservations
	}
	default {
		#<code>
	}
}


    write-host $output

    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\dhcp_" + $frontaID + ".txt"
    (get-date -format "yyyy-MM-dd_hh-mm-ss") *>> $jobFilename
    $output *>> $jobFilename 

    $output = $output -Replace("'",'`')
    $output = $output -Replace('`"','`')

    return $output
}



<#
.SYNOPSIS
Remotely gpupdate PCs.

.DESCRIPTION
Remotely run gpudpate on selected PCs.
Logs result into pcsm database.

.PARAMETER lokalita
ID locality

.PARAMETER computerNames
FQDN names of computers

.PARAMETER author
UCN name of author account

.PARAMETER function
Name of function in case of scheduler
#>
function GPupdate()
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$lokalita,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$computerNames,
		[Parameter(Mandatory = $True, Position = 3)]
		[string]$author,
		[Parameter(Mandatory = $false, Position = 4)]
		[string]$function,
        [Parameter(Mandatory = $true, Position = 5)]
		[string]$frontaID
	)
	if ($function -eq "")
	{
		$function = "gpupdate"
	}
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $author, $function, $frontaID) -ScriptBlock {
			
			."C:\pcsm_backend\testenvironment\functions_include.ps1"
			$computer = $args[0]
			$author = $args[1]
			$function = $args[2]
            $frontaID = $args[3]
 
			

            $first_check = Get-Date -format u
            
            [string]$textBudenie = ""
			#check if computer is up and than run gpupdate
			if (!(Test-Connection -ComputerName $computer -Count 2))
			{
                WakeOnLanPCs -lokalita $lokalita -computerNames $computer -author $author -frontaID $frontaID
                #Start-Sleep 120
                $textBudenie="Prebehlo budenie PC"
            }
			
			
            "PRVOTNE ZASLANIE PRIKAZU GPupdate..."
            try{                                
                Invoke-GPUpdate -Force -Computer $computer -RandomDelayInMinutes 0 -ErrorAction SilentlyContinue
                "PRVOTNE ZASLANIE PRIKAZU GPUPDATE... OK"
                $last_check = Get-Date -format u
                Logger -type "INFO" -text "Pocitac $computer - gpupdate uspesny..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'GPudpate prebehol uspesne', '', '$author', '$frontaID' )"
			
            }
                catch{
                $_.Exception
                "PRVOTNE ZASLANIE PRIKAZU GPUPDATE... ERROR"
                $last_check = Get-Date -format u
                Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo vypnut..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'GPudpate neuspesny', '', '$author', '$frontaID' )"
			
            }
		

			
			
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\gpupdate_" + $_.Name + "_" + $frontaID + ".txt"
	    Receive-Job -Name $_.Name *>> $jobFilename
    }
}





<#
.SYNOPSIS
Remotely restarts PCs.

.DESCRIPTION
Remotely restarts PCs. Remotely restarts PCs and check if computer is restarted in specified time limit.
After remote restart check via ping if computer is down and than up.
Logs result into pcsm database.

.PARAMETER lokalita
ID locality

.PARAMETER computerNames
FQDN names of computers

.PARAMETER author
UCN name of author account

.PARAMETER function
Name of function in case of scheduler
#>
function RestartPCs
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$lokalita,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$computerNames,
		[Parameter(Mandatory = $True, Position = 3)]
		[string]$author,
		[Parameter(Mandatory = $false, Position = 4)]
		[string]$function,
        [Parameter(Mandatory = $true, Position = 5)]
		[string]$frontaID,
        [Parameter(Mandatory = $false, Position = 6)]
		[string]$delay
	)
	if ($function -eq "")
	{
		$function = "restart"
	}
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $broadcastAddress, $author, $function, $lokalita, $frontaID, $delay) -ScriptBlock {
			
			."C:\pcsm_backend\testenvironment\functions_include.ps1"
			$computer = $args[0]
			$broadcastAddress = $args[1]
			$author = $args[2]
			$function = $args[3]
			$lokalita = $args[4]
            $frontaID = $args[5]
            $delay = $args[6]
			
			$i = 0
			$j = 0
			
			$stav = $true
			[string]$textBudenie = ""
			#check if computer is up and than restart or wake up PC.
			if (!(Test-Connection -ComputerName $computer -Count 2))
			{
                WakeOnLanPCs -lokalita $lokalita -computerNames $computer -author $author -frontaID $frontaID
                #Start-Sleep 120
                $textBudenie="Prebehlo budenie PC"
            }
                
				$first_check = Get-Date -format u


                
                "KONTROLA PARAMETRU DELAY..."
                if($delay -match "delay"){
                    "Odoslanie MSG 15 MIN..."
                    $restartTime = (get-date).addMinutes(15)
                    Invoke-Command -ComputerName $computer -ArgumentList $restartTime -command {msg.exe * /server localhost /time:60 "Auto restart of this PC will be forced in 15 minutes ($($args[0])), please log off!"}
                    Start-Sleep -Seconds 60

                }
				
				Restart-Computer -ComputerName $computer -force
				
				while ((Test-Connection -ComputerName $computer -Count 4))
				{
					if ($j -gt $shutDownPingNumber)
					{
						$stav = $false
						break
					}
					$j++
				}
				
				$last_check = Get-Date -format u
				
				if ($stav -ne $false)
				{
					$g = 0
					while (!(Test-Connection -ComputerName $computer -Count 4))
					{
						if ($g -gt ($wakeUpModulo * $wakeUpMaxMagicPackets))
						{
							$stav = $false
							break
						}
						$g++
					}
					
					#number of seconds
					$res = ($j + $g) * 4
					
					if ($stav -eq $false)
					{
						Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo restartovat..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo pocas reštartu zapnút v limite $res sekúnd', '$textBudenie', '$author', '$frontaID' )"
					}
					else
					{
						Logger -type "INFO" -text "Pocitac $computer je restartovany..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol reštartovaný v case $res sekúnd', '$textBudenie', '$author', '$frontaID' )"
					}
				}
				else
				{
					#number of seconds
					$j = $j * 4
					Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo restartovat..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa pocas rectartu nevypol v limite $j sekúnd', '$textBudenie', '$author', '$frontaID' )"
				}
			<#
            }
            else
			{
				WakeOnLanPCs -lokalita $lokalita -computerNames $computer -author $author -function $function     
			}#>
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\restart_" + $_.Name + "_" + $frontaID + ".txt"
	    Receive-Job -Name $_.Name *>> $jobFilename
    }
}




<#
.SYNOPSIS
ADDs UCN\domain users group into UCN\insideLaw group.

.DESCRIPTION
ADDs UCN\domain users group into UCN\insideLaw group when dev access points are not available.
Logs result into pcsm database.

#>
function access(){

    param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$type,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$adGroup,
		[Parameter(Mandatory = $True, Position = 3)]
		[string]$adGroupMember
	)

    [string]$output = (get-date -format "yyyy-MM-dd_hh-mm-ss") + " | " + $type + " | "
    if(Get-ADGroupMember $adGroup | where{$_.samaccountname -eq $adGroupMember}){
        try{
            Remove-ADGroupMember -Identity $adGroup -Members $adGroupMember -ErrorAction stop -Confirm:$false
            $output += "Objekt `"UCN\$adGroupMember`" bol uspesne odstraneny zo skupiny `"$adGroup`""
        }
        catch{
            $output += "Objekt `"UCN\$adGroupMember`" sa nepodarilo odstranit zo skupiny `"$adGroup`"`n"
            $output += $_.exception.message
        }
    }else{
        try{
            Add-ADGroupMember -Identity $adGroup -Members $adGroupMember -ErrorAction stop
            $output += "Objekt `"UCN\$adGroupMember`" bol uspesne pridany do skupiny `"$adGroup`""
        }
        catch{
            $output += "Objekt `"UCN\$adGroupMember`" sa nepodarilo pridat do skupiny `"$adGroup`" `n"
            $output += $_.exception.message
        }    
    }

    Start-Sleep 20

    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\LAW-pristupy_.txt"
    $output *>> $jobFilename 
}




<#
.SYNOPSIS
checks UCN UCO users profile

.DESCRIPTION
Checks if user has permissions for his profile folder than zips and deletes profile files.

#>
function checkProfile(){

    param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$uco,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$operation
	)
    $output = ""

    $profilePath = "\\nfs"+((($uco % 7)+1).ToString())+".ucn.muni.cz\profiles\$uco\"
    $zipfilenameTmp = "C:\pcsm_backend\testenvironment\tmp\"+$uco+"_"+(get-date -format "yyyy-MM-dd-hh-mm-ss")+".zip"
    $zipfilename = $profilePath+$uco+".zip"
    $sourcedir = $profilePath

    #CHECK PROFILE FOLDER PERMISSIONS
    function checkProfilePermissions(){

        Param(
            [string]$uco
        )

        $permissionsCheck = $true
    
        if(Test-Path $profilePath){

            #CHECK USER PERMISSIONS
            #Checks user takeownership and change permissions deny
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "ucn\$uco") -and ($_.FileSystemRights -eq "ChangePermissions, TakeOwnership") -and ($_.AccessControlType -match "Deny") -and ($_.InheritanceFlags -eq "ContainerInherit, ObjectInherit")})){
                $permissionsCheck = $false
            }
            #Checks user delete deny
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "ucn\$uco") -and ($_.FileSystemRights -eq "delete") -and ($_.AccessControlType -match "Deny") -and ($_.InheritanceFlags -eq "none")})){
                $permissionsCheck = $false
            }
            #Checks user fullcontrol allow
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "ucn\$uco") -and ($_.FileSystemRights -eq "FullControl") -and ($_.AccessControlType -match "Allow") -and ($_.InheritanceFlags -eq "ContainerInherit, ObjectInherit") })){
                $permissionsCheck = $false
            }


            #CHECK SYSTEM AND ACCMGR PERMISSIONS
            #Checks NT AUTHORITY\SYSTEM fullcontrol allow
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "NT AUTHORITY\SYSTEM") -and ($_.FileSystemRights -eq "FullControl") -and ($_.AccessControlType -match "Allow") -and ($_.InheritanceFlags -eq "ContainerInherit, ObjectInherit") })){
                $permissionsCheck = $false
            }
            #Checks UCN\AccMgr fullcontrol allow
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "UCN\AccMgr") -and ($_.FileSystemRights -eq "FullControl") -and ($_.AccessControlType -match "Allow") -and ($_.InheritanceFlags -eq "ContainerInherit, ObjectInherit") })){
                $permissionsCheck = $false
            }

            #Checks BUILTIN\Administrators fullcontrol allow
            if(!((get-acl $profilePath).Access | Where-Object {($_.IdentityReference -eq "BUILTIN\Administrators") -and ($_.FileSystemRights -eq "FullControl") -and ($_.AccessControlType -match "Allow") -and ($_.InheritanceFlags -eq "ContainerInherit, ObjectInherit") })){
                $permissionsCheck = $false
            }
    
        }else{
            $permissionsCheck = $false
        }

        return $permissionsCheck
    }

    #ZIP PROFILE
    function ZipFiles( $zipfilenameFunction, $sourcedirFunction )
    {
       
       Add-Type -Assembly System.IO.Compression.FileSystem
       $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal 
       [System.IO.Compression.ZipFile]::CreateFromDirectory($sourcedirFunction, $zipfilenameFunction, $compressionLevel, $false) 
    }




    if($operation -match "checkPermission"){
        if(checkProfilePermissions -uco $uco){ 
            $output += "Uzivatelske opravnenia su v poriadku. "
        }else{
            if(Test-Path $profilePath){
                
                $output += "Uzivatelske opravnenia niesu v poriadku. "
                
                #oprava opravneni
                $ErrorActionPreference = "stop"
                
                try{
                    icacls $profilePath /grant "ucn\$uco`:(OI)(CI)F" | Out-Null
                    icacls $profilePath /deny "ucn\$uco`:(OI)(CI)(WDAC)" | Out-Null
                    icacls $profilePath /deny "ucn\$uco`:(OI)(CI)(WO)" | Out-Null
                    icacls $profilePath /deny "ucn\$uco`:(D)" | Out-Null
                    icacls $profilePath /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" | Out-Null
                    icacls $profilePath /grant "ucn\AccMgr:(OI)(CI)F" | Out-Null
                    icacls $profilePath /grant "Administrators:(OI)(CI)F" | Out-Null
                    icacls $profilePath /setowner "ucn\AccMgr" | Out-Null
                    $output += "Uzivatelske opravnenia boli zmene. "
                }catch{
                    write-warning "ERROR message occured:"
                    #$_.exception
                    $output += "Uzivatelske opravnenia sa nepodarilo zmenit"
                    $output += "`nChybove hlasenie: "+$_.exception
                }

            }else{
                $output+="Adresar s profilom neexistuje"
            }        
        }
    }

    if($operation -match "zipAndDelete"){

        $ErrorActionPreference = "stop"
        try{        
            #Adds ntfs full control rights for ucn\pcsm
            icacls $profile /grant "ucn\pcsm:(OI)(CI)F" | Out-Null
        
            #Zips profile data to tmp folder
            Write-host "Zipping $sourcedir folder to $zipfilenameTmp "
            ZipFiles $zipfilenameTmp $sourcedir 
            
            #Removes zipped data from profile
            Remove-Item -Force -Recurse $profilePath*

            #Copies profile zip data from tmp folder to profile folder
            write-host "Coping $zipfilenameTmp to $zipfilename"
            Copy-Item $zipfilenameTmp $zipfilename -Force 

            #Removes data from tmp
            Remove-Item -Force $zipfilenameTmp 
            

            $output += "`n`nUzivatelske data boli ulozene v subore $uco.zip. Povodny profil bol odstraneny. "
        }catch{
        
            write-warning "ERROR message occured:"
            #$_.exception
            $output += "`nChybove hlasenie: "+$_.exception

        }finally{
            #Removes ntfs full control rights for ucn\pcsm
            icacls $profile /remove:g "ucn\pcsm" | Out-Null
        }
        $ErrorActionPreference = 'continue'
    }

    write-host $output

    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\checkProfile_.txt"
    $output *>> $jobFilename 

    $output = $output -Replace("'",'`')
    $output = $output -Replace('`"','`')
    return $output
}



<#
.SYNOPSIS
Restarts irkala CPS services

.DESCRIPTION
Restarts irkala CPS services (OVSS defined)

#>
function Irkala_CPS(){

    $serviceName = "Irkalla_CPS"
    $output = ""
    
    $ErrorActionPreference = "stop"
    try{

        if((Get-Service -ComputerName altariel1.ucn.muni.cz | Where-Object {$_.Name -match $serviceName}).Status -match "Stopped"){
        
            (Get-Service -ComputerName altariel1.ucn.muni.cz | Where-Object {$_.Name -match $serviceName}) | Start-Service

        }else{
        
            (Get-Service -ComputerName altariel1.ucn.muni.cz | Where-Object {$_.Name -match $serviceName}) | Stop-Service

            Start-Sleep 3

            (Get-Service -ComputerName altariel1.ucn.muni.cz | Where-Object {$_.Name -match $serviceName}) | Start-Service

        }

        Start-Sleep 3

        if((Get-Service -ComputerName altariel1.ucn.muni.cz | Where-Object {$_.Name -match $serviceName}).Status -match "Running"){

            $output += "Sluzbu sa podarilo restartovat"

        }else{
            $output += "Chybove hlasenie:`n"
            $output += "Sluzbu sa nepodarilo restartovat"

        }

    }catch{
        write-warning "ERROR message occured:"
        #$_.exception
        $output += "Sluzbu sa nepodarilo restartovat"
        $output += "`nChybove hlasenie: "+$_.exception
    }

    $ErrorActionPreference = 'continue'

    write-host $output

    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\Irkala_CPS_.txt"
    $output *>> $jobFilename 

    $output = $output -Replace("'",'`')
    $output = $output -Replace('`"','`')
    return $output
}


<#
.SYNOPSIS
Restarts SAFEQ services

.DESCRIPTION
Restarts SAFEQ services

#>
function safeq(){

# safeq services - must be started in defined order
$safeqServices = @("YSoftSafeQLDAPReplicator", "YSoftWeb", "YSoftSafeQTerminalServer", "YSoftSafeQCMLDBS", "YSoftSafeQCML")

    $output = ""
    [INT]$waitTime = 3

    $safeqServices | foreach{

        $serviceName = $_
        $serverName = "q5-cml-mu.ucn.muni.cz"
  
        $ErrorActionPreference = "stop"
        try{

            if((Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}).Status -match "Stopped"){
        
                # DO NOTHING
                #(Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}) | Start-Service

            }else{
        
                (Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}) | Stop-Service            

            }
            
            Start-Sleep -Seconds $waitTime

            if((Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}).Status -match "Stopped"){

                $output += "Sluzbu $serviceName sa podarilo zastavit`n"

            }else{
                $output += "Chybove hlasenie:`n"
                $output += "Sluzbu $serviceName sa nepodarilo zastavit`n"

            }

        }catch{
            write-warning "ERROR message occured:"
            #$_.exception
            $output += "Sluzbu $serviceName sa nepodarilo zastavit`n"
            $output += "`nChybove hlasenie: "+$_.exception
        }

    }

    [array]::Reverse($safeqServices)

    Start-Sleep -Seconds (6*$waitTime)

    $safeqServices | foreach{

        $serviceName = $_
        $serverName = "q5-cml-mu.ucn.muni.cz"
    
        $ErrorActionPreference = "stop"
        try{

            if((Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}).Status -match "Running"){
        
                # DO NOTHING
                #(Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}) | Start-Service

            }else{
        
                (Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}) | Start-Service            

            }

            Start-Sleep -Seconds $waitTime

            if((Get-Service -ComputerName $serverName | Where-Object {$_.Name -match $serviceName}).Status -match "Running"){

                $output += "Sluzbu $serviceName sa podarilo nastartovat`n"

            }else{
                $output += "Chybove hlasenie:`n"
                $output += "Sluzbu $serviceName sa nepodarilo nastartovat`n"

            }

        }catch{
            write-warning "ERROR message occured:"
            #$_.exception
            $output += "Sluzbu $serviceName sa nepodarilo nastartovat`n"
            $output += "`nChybove hlasenie: "+$_.exception
        }

    }



    $ErrorActionPreference = 'continue'

    write-host $output

    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\safeq_.txt"
    $output *>> $jobFilename 

    $output = $output -Replace("'",'`')
    $output = $output -Replace('`"','`')
    return $output
}





<#
.SYNOPSIS
Change state of PCs.

.DESCRIPTION
Remotely change state of PCs. Links GPO policy to specified organization unit in active directory and remotely restarts PCs.
Logs result into pcsm database.

.PARAMETER typ
Type of state => odpovedni, student, standard

.PARAMETER lokalita
ID locality

.PARAMETER author
UCN name of author account

.PARAMETER function
Name of function in case of scheduler
#>
function ChangeStatePCs()
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$typ,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$lokalita,
		[Parameter(Mandatory = $True, Position = 3)]
		[string]$author,
		[Parameter(Mandatory = $false, Position = 4)]
		[string]$function,
        [Parameter(Mandatory = $false, Position = 5)]
		[string]$frontaID
	)
	if ($function -eq "")
	{
		$function = "rezim"
	}
	
	
	$idLokalita = $lokalita
	
	$dn = FindLokalitaOu -idlokalita $idLokalita
	
	#generates list of computers FQDN and domain name by locality from Active Directory via LDAP
	$domenaRaw = $dn -split "DC="
	$domenaRaw[1] = $domenaRaw[1] -replace ".$"
	$domenaRaw[2] = $domenaRaw[2] -replace ".$"
	$domenaRaw[3] = $domenaRaw[3] -replace ".$"
	$domena = $domenaRaw[1] + "." + $domenaRaw[2] + "." + $domenaRaw[3] + "." + $domenaRaw[4]
	
	$ldapSettings = "LDAP://$dn"
	$root = [ADSI]$ldapSettings
	$search = [adsisearcher]$root
	$Search.Filter = "(&(objectCategory=computer))"
	$colResults = $Search.FindAll()
	$computerNames = ""
	foreach ($i in $colResults)
	{
		$computerNames += "" + $i.Properties.Item('cn') + "." + $domena + ","
	}
	
	$computerNames = $computerNames -replace ".$"

    Logger -type "INFO" -text "$computerNames"
	
	#Link GPO policy by type of state
	
    switch ($typ)
	{
		"Odpovedník" {
  
            Remove-GPLink -Name "UCN, CONFIG, CORE, LogonMessageAndLastUser" -Domain "ucn.muni.cz" -Target "$dn"

			Remove-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn"
			New-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn" -LinkEnabled Yes
		}
		"Študent" {
            Remove-GPLink -Name "UCN, CONFIG, CORE, LogonMessageAndLastUser" -Domain "ucn.muni.cz" -Target "$dn"
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn"
			New-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn" -LinkEnabled Yes
		}
		"Štandard" {
            
            #New-GPLink -Guid fa16e2db-3bcb-4f37-9084-a40c38726e17 -Domain "ucn.muni.cz" -Target "$dn" -LinkEnabled Yes
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn"
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn"
		}
		default
		{
            Remove-GPLink -Name "UCN, CONFIG, CORE, LogonMessageAndLastUser" -Domain "ucn.muni.cz" -Target "$dn"
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn"
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn"
		}
	}
	
    Start-Sleep -Seconds 60
	
	$computers = $computerNames.Split(",")
	
	#remotely update GPO policy on PCs and restart PCs, In case of PC is down, wake up PC and remotely update policy.
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $broadcastAddress, $author, $function, $typ, $idLokalita, $frontaID) -ScriptBlock {
			
			."C:\pcsm_backend\testenvironment\functions_include.ps1"
			$computer = $args[0]
			$broadcastAddress = $args[1]
			$author = $args[2]
			$function = $args[3]
			$typ = $args[4]
            $idlokalita = $args[5]
            $frontaID = $args[6]
			
			$first_check = Get-Date -format u
			if (Test-Connection -ComputerName $computer -Count 2)
			{
                $i=1
                while((!(Test-WSMan -ComputerName $computer)) -and ($i -lt 6)){
                    Start-Sleep 60
                    echo $i
                    $i++
                }

				if (($s = new-pssession -computername $computer))
				{
                    
                    switch ($typ){
                        "Odpovedník" {
                            invoke-command -session $s {
                                Push-Location
                                Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                Set-ItemProperty . DefaultDomainName "UPS"
                                Set-ItemProperty . DefaultPassword "odpovednik"
                                Set-ItemProperty . DefaultUserName "odpovednik"
                                Set-ItemProperty . AutoAdminLogon "1"
                                Pop-Location    
                            }
		                }
		                "Študent" {
                            invoke-command -session $s {
                                Push-Location
                                Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                Set-ItemProperty . DefaultDomainName "UPS"
                                Set-ItemProperty . DefaultPassword "student"
                                Set-ItemProperty . DefaultUserName "student"
                                Set-ItemProperty . AutoAdminLogon "1"
                                Pop-Location    
                            }
		                }
		                "Štandard" {
                            Invoke-Command -Session $s {
                                if((Get-ItemProperty "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"-Name DefaultPassword -ea 0).DefaultPassword){
                                    Remove-ItemProperty -Name "DefaultPassword" -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                }
                                Push-Location
                                Set-ItemProperty . DefaultDomainName "UCN"
                                Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                Set-ItemProperty . DefaultUserName "Administrator"
                                Set-ItemProperty . AutoAdminLogon "0"
                                Pop-Location
                            }
		                }
                    }

					invoke-command -session $s {
						echo N `n N | gpupdate /force
						shutdown -r -t 0 -f
					}
					exit-pssession
                    $last_check = get-date -format u
					Logger -type "INFO" -text "Pocitac $computer zmenil rezim..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol kontaktovaný a reštartuje sa', 'Režim: $typ', '$author', '$frontaID' )"
				}
				else
				{
					$last_check = get-date -format u
					Logger -type "ERROR" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo kontaktovat, WinRM nieje dostupna', 'Režim: $typ', '$author', '$frontaID' )"
				}
				
			}
			else
			{
				WakeOnLanPCs -lokalita $idlokalita -computerNames $computer -author $author -frontaID $frontaID
				if (Test-Connection -ComputerName $computer -Count 2)
				{
					$i=1
                    while((!(Test-WSMan -ComputerName $computer)) -and ($i -lt 6)){
                        Start-Sleep 60
                        echo $i
                        $i++
                    }

					if (($s = new-pssession -computername $computer))
					{
                        switch ($typ){
                            "Odpovedník" {
                                invoke-command -session $s {
                                    Push-Location
                                    Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                    Set-ItemProperty . DefaultDomainName "UPS"
                                    Set-ItemProperty . DefaultPassword "odpovednik"
                                    Set-ItemProperty . DefaultUserName "odpovednik"
                                    Set-ItemProperty . AutoAdminLogon "1"
                                    Pop-Location    
                                }
		                    }
		                    "Študent" {
                                invoke-command -session $s {
                                    Push-Location
                                    Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                    Set-ItemProperty . DefaultDomainName "UPS"
                                    Set-ItemProperty . DefaultPassword "student"
                                    Set-ItemProperty . DefaultUserName "student"
                                    Set-ItemProperty . AutoAdminLogon "1"
                                    Pop-Location    
                                }
		                    }
		                    "Štandard" {
                                Invoke-Command -Session $s {
                                    if((Get-ItemProperty "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"-Name DefaultPassword -ea 0).DefaultPassword){
                                        Remove-ItemProperty -Name "DefaultPassword" -Path "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                    }
                                    Push-Location
                                    Set-ItemProperty . DefaultDomainName "UCN"
                                    Set-Location "hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
                                    Set-ItemProperty . DefaultUserName "Administrator"
                                    Set-ItemProperty . AutoAdminLogon "0"
                                    Pop-Location
                                }
		                    }
                        }
						invoke-command -session $s {
							echo N `n N | gpupdate /force
							shutdown -r -t 0 -f
						}
						Exit-PSSession
                        $last_check = get-date -format u
						Logger -type "INFO" -text "Pocitac $computer zmenil rezim..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol kontaktovaný a reštartuje sa', 'Režim: $typ, Prebehlo budenie systemu', '$author', '$frontaID' )"
					}
					else
					{
						$last_check = get-date -format u
						Logger -type "ERROR" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo kontaktovat', 'Rezim: $typ, Prebehlo budenie systemu', '$author', '$frontaID' )"
					}
				}
				else
				{
					$last_check = get-date -format u
					Logger -type "INFO" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Na pocítaci sa nepodarilo zmenit režim', 'Režim: $typ', '$author', '$frontaID')"
				}
			}
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\testenvironment\transcriptLog\state_" + $_.Name + "_" + $frontaID + ".txt"
	    Receive-Job -Name $_.Name *>> $jobFilename
    }
    
}

<#
.SYNOPSIS
Listener for tasks from databse queue

.DESCRIPTION
Check new tasks in databse queue and executes functions via item from queue
#>
function Listener
{
	#check FIFO and update state of items from waitting to running
	$fronta = New-Object System.Data.DataSet
	$fronta = mysqlQuerySelect -query "SELECT * FROM fronta WHERE status='WAITING';UPDATE fronta SET status='RUNNING' WHERE status='WAITING';"
	$dataTable = new-object System.Data.DataTable
	$dataTable = $fronta.Tables[0]
	
	$dataTable | ForEach-Object{

        [string]$command = $_.command
		[string]$parameter = $_.parameter
		[string]$taskId = $_.id
		[string]$author = $_.author
        
		
		$data = $parameter.Split(';')
		
		switch ($command)
		{
			"budenie" {
				Logger -type "INFO" -text "START budenie TASK ID $taskId"
				WakeOnLanPCs -lokalita $data[0] -computerNames $data[1] -author $author -frontaID $taskId
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END budenie TASK ID $taskId"
			}
			"vypnutie" {
				Logger -type "INFO" -text "START vypinanie TASK ID $taskId"
				ShutdownPCs -lokalita $data[0] -computerNames $data[1] -author $author -frontaID $taskId -delay $data[2]
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END vypinanie TASK ID $taskId"
			}
            "gpupdate" {
				Logger -type "INFO" -text "START gpupdate TASK ID $taskId"
				gpupdate -lokalita $data[0] -computerNames $data[1] -author $author -frontaID $taskId
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END gpupdate TASK ID $taskId"
			}
			"restart" {
				Logger -type "INFO" -text "START restart TASK ID $taskId"
				RestartPCs -lokalita $data[0] -computerNames $data[1] -author $author -frontaID $taskId -delay $data[2]
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END restart TASK ID $taskId"
			}
			"rezim" {
				Logger -type "INFO" -text "START rezim TASK ID $taskId"
				ChangeStatePCs -typ $data[0] -lokalita $data[1] -author $author -frontaID $taskId
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END rezim TASK ID $taskId"
			}
            "pristupy"{
                Logger -type "INFO" -text "START law-pristupy TASK ID $taskId"
				access -type $data[0] -adGroup $data[1] -adGroupMember $data[2]
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END law-pristupy TASK ID $taskId"
            }
            "oss"{
                Logger -type "INFO" -text "START checkProfile TASK ID $taskId"
				$result = checkProfile -uco $data[0] -operation $data[1]
                $result = $parameter+";"+$result
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE', parameter='$result' WHERE id='$taskId'"
				Logger -type "INFO" -text "END oss TASK ID $taskId"
            }
            "irkala_cps"{
                Logger -type "INFO" -text "START Irkala_CPS TASK ID $taskId"
				$result = Irkala_CPS
                $result = $parameter+";"+$result
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE', parameter='$result' WHERE id='$taskId'"
				Logger -type "INFO" -text "END Irkala_cPS TASK ID $taskId"
            }
            "safeq"{
                Logger -type "INFO" -text "START SAFEQ TASK ID $taskId"
				$result = SAFEQ
                $result = $parameter+";"+$result
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE', parameter='$result' WHERE id='$taskId'"
				Logger -type "INFO" -text "END SAFEQ TASK ID $taskId"
            }
            "dhcp"{
                Logger -type "INFO" -text "START DHCP TASK ID $taskId"
				$result = dhcp -lokalita $data[1] -author $author -frontaID $taskId -action $data[0] -ClientIPAddress $data[2] -mac $data[3]
                $result = $parameter+";"+$result
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE', parameter='$result' WHERE id='$taskId'"
				Logger -type "INFO" -text "END DHCP TASK ID $taskId"
            }
			default { }
		}
	}
}

<#
.SYNOPSIS
Listener for once scheduled tasks from databse queue

.DESCRIPTION
Check new once scheduled tasks in databse queue and executes functions via item from queue
#>
function SchedulerOnce
{
	#check tasks from database queue by time with precision to minute.
	$time = Get-Date -Format "yyyy-MM-dd HH:mm"
	$fronta = New-Object System.Data.DataSet
	$fronta = mysqlQuerySelect -query "SELECT * FROM scheduler WHERE disabled<>'Ano' AND time LIKE '$time%' AND typ='once'"
	$dataTable = new-object System.Data.DataTable
	$dataTable = $fronta.Tables[0]
	
	$dataTable | foreach{
		

		[string]$idlokalita = $_.id_lokalita
		[string]$funkcia = $_.funkcia
		[string]$taskId = $_.id
		[string]$note = $_.note
		[string]$author = $_.author
        [string]$emailConfirm = $_.emailConfirm
		
		$lokalita = New-Object System.Data.DataSet
		$lokalita = MysqlQuerySelect -query "SELECT name FROM lokality WHERE id='$idlokalita' LIMIT 1"
		$lokalitaData = new-object System.Data.DataTable
	    $lokalitaData = $lokalita.Tables[0]
	    $lokalitaName = $lokalitaData.rows[0].name
		
		$dn = FindLokalitaOu -idlokalita $idLokalita
		
		#generates list of computers and domain name by locality from Active Directory via LDAP
		$domenaRaw = $dn -split "DC="
		$domenaRaw[1] = $domenaRaw[1] -replace ".$"
		$domenaRaw[2] = $domenaRaw[2] -replace ".$"
		$domenaRaw[3] = $domenaRaw[3] -replace ".$"
		$domena = $domenaRaw[1] + "." + $domenaRaw[2] + "." + $domenaRaw[3] + "." + $domenaRaw[4]
		
		$ldapSettings = "LDAP://$dn"
		$root = [ADSI]$ldapSettings
		$search = [adsisearcher]$root
		$Search.Filter = "(&(objectCategory=computer))"
		$colResults = $Search.FindAll()
		$computerNames = ""
		
		foreach ($i in $colResults){
			$computerNames += "" + $i.Properties.Item('cn') + "." + $domena + ","
		}
		
		$computerNames = $computerNames -replace ".$"
		$startDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
		switch ($funkcia)
		{
			"budenie" {
				Logger -type "INFO" -text "START SCHEDULER budenie Scheduler TASK ID $taskId"
				WakeOnLanPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
				Logger -type "INFO" -text "END CHEDULER budenie Scheduler TASK ID $taskId"
			}
			"vypinanie" {
				Logger -type "INFO" -text "START SCHEDULER vypinanie Scheduler TASK ID $taskId"
				ShutdownPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
				Logger -type "INFO" -text "END CHEDULER vypinanie Scheduler TASK ID $taskId"
			}
			"restart" {
				Logger -type "INFO" -text "START SCHEDULER restart Scheduler TASK ID $taskId"
				RestartPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
				Logger -type "INFO" -text "END SCHEDULER restart Scheduler TASK ID $taskId"
			}
			"rezim" {
				Logger -type "INFO" -text "START SCHEDULER rezim Scheduler TASK ID $taskId"
				ChangeStatePCs -lokalita $idlokalita -typ $note -author $author -function "scheduler" -frontaID $taskId
				Logger -type "INFO" -text "END SCHEDULER rezim Scheduler TASK ID $taskId"
			}
			default { }
		}
        #MAIL to CPSADM
            $stopDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            #$operacia = $funkcia
            #$poznamka = $note
            #send-mailmessage -from "PCSM <cuchran@ics.muni.cz>" -to "<cpsadm@ics.muni.cz>" -subject "PCSM - Uskutocnenie planovanej ulohy" -BodyAsHtml -body "V case <b>$startDate - $datum</b> bola na lokalite: <b>$lokalitaName</b> spustena naplanovana operacia: <b>$operacia $poznamka</b>. Log z operacie je dostupny v aplikacii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b><br><br>Tento email je automaticky generovany aplikaciou PCSM." -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
            
            mailCPS -mailTo $emailConfirm -dateFrom $startDate -dateTo $stopDate -poznamka $note -operacia $funkcia -lokalitaName $lokalitaName -frontaID $taskId
        
    }
}

<#
.SYNOPSIS
Listener for repeat scheduled tasks from databse queue

.DESCRIPTION
Check new repeat scheduled tasks in databse queue and executes functions via item from queue
#>
function SchedulerRepeat
{
	#check queue by time with precision to minute
	$time = Get-Date -Format "HH:mm"
	$fronta = New-Object System.Data.DataSet
	$fronta = mysqlQuerySelect -query "SELECT scheduler.emailConfirm, scheduler.id, scheduler.id_lokalita, scheduler.name, scheduler.typ, scheduler.funkcia, scheduler.author, scheduler_time.id, scheduler.note, scheduler_time.time, scheduler_time.pondelok, scheduler_time.utorok, scheduler_time.streda, scheduler_time.stvrtok, scheduler_time.piatok, scheduler_time.sobota, scheduler_time.nedela, scheduler_time.id_scheduler FROM scheduler INNER JOIN scheduler_time ON scheduler.id=scheduler_time.id_scheduler WHERE scheduler.disabled<>'Ano' AND scheduler.typ='repeat' AND scheduler_time.time LIKE '$time%'"
	$dataTable = new-object System.Data.DataTable
	$dataTable = $fronta.Tables[0]
	
	$day = Get-Date -Format "dddd"
	$run = $false
	$dataTable | ForEach-Object{
		
		$pondelok = $_.pondelok
		$utorok = $_.utorok
		$streda = $_.streda
		$stvrtok = $_.stvrtok
		$piatok = $_.piatok
		$sobota = $_.sobota
		$nedela = $_.nedela
		
		switch ($day)
		{
			"Monday" {
				if ($pondelok -eq "Áno")
				{
					$run = $true
				}
			}
			"Tuesday" {
				if ($utorok -eq "Áno")
				{
					$run = $true
				}
			}
			"Wednesday" {
				if ($streda -eq "Áno")
				{
					$run = $true
				}
			}
			"Thursday" {
				if ($stvrtok -eq "Áno")
				{
					$run = $true
				}
			}
			"Friday" {
				if ($piatok -eq "Áno")
				{
					$run = $true
				}
			}
			"Saturday" {
				if ($sobota -eq "Áno")
				{
					$run = $true
				}
			}
			"Sunday" {
				if ($nedela -eq "Áno")
				{
					$run = $true
				}
			}
			default
			{
				$run = $false
			}
			
		}
		
		if ($run -eq $true)
		{
			[string]$idlokalita = $_.id_lokalita
			[string]$funkcia = $_.funkcia
			[string]$taskId = $_.id
			[string]$note = $_.note
			[string]$author = $_.author
            [string]$emailConfirm = $_.emailConfirm
			
			$lokalita = New-Object System.Data.DataSet
			$lokalita = MysqlQuerySelect -query "SELECT name FROM lokality WHERE id='$idlokalita' LIMIT 1"
			$lokalitaData = new-object System.Data.DataTable
	        $lokalitaData = $lokalita.Tables[0]
			$lokalitaName = $lokalitaData.rows[0].name
			
			$dn = FindLokalitaOu -idlokalita $idLokalita
			
			#generates list of computers and domain name by locality from Active Directory via LDAP
			$domenaRaw = $dn -split "DC="
			$domenaRaw[1] = $domenaRaw[1] -replace ".$"
			$domenaRaw[2] = $domenaRaw[2] -replace ".$"
			$domenaRaw[3] = $domenaRaw[3] -replace ".$"
			$domena = $domenaRaw[1] + "." + $domenaRaw[2] + "." + $domenaRaw[3] + "." + $domenaRaw[4]
			
			$ldapSettings = "LDAP://$dn"
			$root = [ADSI]$ldapSettings
			$search = [adsisearcher]$root
			$Search.Filter = "(&(objectCategory=computer))"
			$colResults = $Search.FindAll()
			$computerNames = ""
			foreach ($i in $colResults){
				$computerNames += "" + $i.Properties.Item('cn') + "." + $domena + ","
			}
			
			$computerNames = $computerNames -replace ".$"
			$startDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
			switch ($funkcia)
			{
				"budenie" {
					Logger -type "INFO" -text "START SCHEDULER budenie Scheduler TASK ID $taskId"
					WakeOnLanPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
					Logger -type "INFO" -text "END CHEDULER budenie Scheduler TASK ID $taskId"
				}
				"vypinanie" {
					Logger -type "INFO" -text "START SCHEDULER vypinanie Scheduler TASK ID $taskId"
					ShutdownPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
					Logger -type "INFO" -text "END CHEDULER vypinanie Scheduler TASK ID $taskId"
				}
				"restart" {
					Logger -type "INFO" -text "START SCHEDULER restart Scheduler TASK ID $taskId"
					RestartPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler" -frontaID $taskId
					Logger -type "INFO" -text "END SCHEDULER restart Scheduler TASK ID $taskId"
				}
				"rezim" {
					Logger -type "INFO" -text "START SCHEDULER rezim Scheduler TASK ID $taskId"
					ChangeStatePCs -lokalita $idlokalita -typ $note -author $author -function "scheduler" -frontaID $taskId
					Logger -type "INFO" -text "END SCHEDULER rezim Scheduler TASK ID $taskId"
				}
				default { }
			}
            #MAIL to CPSADM
            $stopDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            #$operacia = $funkcia
            #$poznamka = $note
            #send-mailmessage -from "PCSM <cuchran@ics.muni.cz>" -to "<cpsadm@ics.muni.cz>" -subject "PCSM - Uskutocnenie planovanej ulohy" -BodyAsHtml -body "V case <b>$startDate - $datum</b> bola na lokalite: <b>$lokalitaName</b> spustena naplanovana operacia: <b>$operacia $poznamka</b>. Log z operacie je dostupny v aplikacii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b><br><br>Tento email je automaticky generovany aplikaciou PCSM." -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
            #mailCPS -mailTo "cpsadm@ics.muni.cz" -dateFrom $startDate -dateTo $stopDate -poznamka $note -operacia $funkcia -lokalitaName $lokalitaName -computers $computerNames
            mailCPS -mailTo $emailConfirm -dateFrom $startDate -dateTo $stopDate -poznamka $note -operacia $funkcia -lokalitaName $lokalitaName -frontaID $taskId
		}
	}
}



#runs listeners
switch ($operationType)
{
	"task" {
		Listener
	}
	"scheduler" {
		SchedulerOnce
		SchedulerRepeat
	}
	default
	{
		
	}
}


#Stop-Transcript





