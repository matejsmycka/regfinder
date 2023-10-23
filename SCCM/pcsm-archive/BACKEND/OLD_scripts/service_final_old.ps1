Param(
	[Parameter(Mandatory = $True, Position = 1)]
	[string]$operationType
)


#includes script with functions because of paralel processing via start-job
."C:\pcsm_backend\functions_include.ps1"



function mailCPS{
     param (
		    [Parameter(Mandatory = $True, Position = 1)]
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
		    [string]$computers
	 )  
	

    [string]$log=""

    $computersSplit = $computers.Split(",")
    $computersSplit = $computersSplit | Sort-Object

	foreach ($pc in $computersSplit){

        $info = New-Object System.Data.DataSet
	    $info = mysqlQuerySelect -query "SELECT * FROM logs WHERE computer_name='$pc' AND first_check>='$dateFrom' AND last_check<='$dateTo' AND process='scheduler' ORDER BY computer_name"
	    $dataTable = new-object System.Data.DataTable
	    $dataTable = $info.Tables[0] 
        $computerName = $dataTable.rows[0].computer_name 
        $computer_status = $dataTable.rows[0].status
        if($dataTable.rows[0] -ne $null){
            if($computer_status -eq "FAILED"){
                $log += "$computerName - <font style='color:#ff0000'>$computer_status</font><br>"
            }else{
                $log += "$computerName - <font style='color:#00b400'>$computer_status</font><br>"
            }
        }
    }

    $mailText= "<html>
                    <body style='font-size:12px;'>
                        Lokalita: <b>$lokalitaName</b>   <br>
                        Typ operácie: <b>$operacia $poznamka</b>  <br> <br>
                        Spustenie operácie: <b>$dateFrom  </b>  <br>
                        Koniec operácie: <b>$dateTo</b>  <br> <br>


                        Log z operácie je dostupný v aplikácii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b>  <br><br> 

                        <b>Log strojov:</b><br><br> 
                        $log
                        <br>

                        Tento email je automaticky generovaný aplikáciou PCSM.
                    </body>
                </html>"
    #MAIL to CPSADM
    send-mailmessage -from "PCSM <pcsm@ics.muni.cz>" -to "<$mailTo>" -subject "PCSM - $lokalitaName - $operacia $poznamka" -BodyAsHtml -body $mailText -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
		
	

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
		[string]$function
	)
	if ($function -eq "")
	{
		$function = "vypinanie"
	}
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $author, $function) -ScriptBlock {
			
			."C:\pcsm_backend\functions_include.ps1"
			$computer = $args[0]
			$author = $args[1]
			$function = $args[2]
			
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
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Vypnutie neprebehlo vo vyhradenom casovom limite', '', '$author' )"
			}
			else
			{
				Logger -type "INFO" -text "Pocitac $computer je vypnuty..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Vypnutie prebehlo vo vyhradenom casovom limite', '', '$author' )"
			}
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\transcriptLog\shutdown_" + $_.Name + "_" + (get-date -format "yyyy-MM-dd_hh-mm-ss") + ".txt"
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
		[string]$function
	)
	if ($function -eq "")
	{
		$function = "restart"
	}
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		Start-Job -Name $computer -ArgumentList @($computer, $broadcastAddress, $author, $function, $lokalita) -ScriptBlock {
			
			."C:\pcsm_backend\functions_include.ps1"
			$computer = $args[0]
			$broadcastAddress = $args[1]
			$author = $args[2]
			$function = $args[3]
			$lokalita = $args[4]
			
			$i = 0
			$j = 0
			
			$stav = $true
			[string]$textBudenie = ""
			#check if computer is up and than restart or wake up PC.
			if (!(Test-Connection -ComputerName $computer -Count 2))
			{
                WakeOnLanPCs -lokalita $lokalita -computerNames $computer -author $author
                #Start-Sleep 120
                $textBudenie="Prebehlo budenie PC"
            }
                
				$first_check = Get-Date -format u
				
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
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo pocas reštartu zapnút v limite $res sekúnd', '$textBudenie', '$author' )"
					}
					else
					{
						Logger -type "INFO" -text "Pocitac $computer je restartovany..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol reštartovaný v case $res sekúnd', '$textBudenie', '$author' )"
					}
				}
				else
				{
					#number of seconds
					$j = $j * 4
					Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo restartovat..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa pocas rectartu nevypol v limite $j sekúnd', '$textBudenie', '$author' )"
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
	    $jobFilename = "C:\pcsm_backend\transcriptLog\restart_" + $_.Name + "_" + (get-date -format "yyyy-MM-dd_hh-mm-ss") + ".txt"
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
function LAW-access(){

    $adGroup = "avmedia_install"
    $adGroupMember = "avmedia" 
    $output = ""
    if(Get-ADGroupMember $adGroup | where{$_.samaccountname -eq $adGroupMember}){
        try{
            Remove-ADGroupMember -Identity $adGroup -Members $adGroupMember -ErrorAction stop -Confirm:$false
            $output += "Objekt `"UCN\$adGroupMember`" bol uspesne odstraneny zo skupiny `"UCN\$adGroup`""
        }
        catch{
            $output += "Objekt `"UCN\$adGroupMember`" sa nepodarilo odstranit zo skupiny `"UCN\$adGroup`"`n"
            $output += $_.exception.message
        }
    }else{
        try{
            Add-ADGroupMember -Identity $adGroup -Members $adGroupMember -ErrorAction stop
            $output += "Objekt `"UCN\$adGroupMember`" bol uspesne pridany do skupiny `"UCN\$adGroup`""
        }
        catch{
            $output += "Objekt `"UCN\$adGroupMember`" sa nepodarilo pridat do skupiny `"UCN\$adGroup`" `n"
            $output += $_.exception.message
        }    
    }

    $jobFilename = "C:\pcsm_backend\transcriptLog\LAW-pristupy_" + (get-date -format "yyyy-MM-dd_hh-mm-ss") + ".txt"
    $output *>> $jobFilename 
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
		[string]$function
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
	
	#Link GPO policy by type of state
	
    switch ($typ)
	{
		"Odpovedník" {
  
            Remove-GPLink -Guid fa16e2db-3bcb-4f37-9084-a40c38726e17 -Domain "ucn.muni.cz" -Target "$dn"

			Remove-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn"
			New-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn" -LinkEnabled Yes
		}
		"Študent" {
            Remove-GPLink -Guid fa16e2db-3bcb-4f37-9084-a40c38726e17 -Domain "ucn.muni.cz" -Target "$dn"
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
            #New-GPLink -Guid fa16e2db-3bcb-4f37-9084-a40c38726e17 -Domain "ucn.muni.cz" -Target $dn -LinkEnabled Yes
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon, student + C:\StudentTMP" -Domain "ups.ucn.muni.cz" -Target "$dn"
			Remove-GPLink -Name "UPS, Anonymous, AllowLogon odpovednik" -Domain "ups.ucn.muni.cz" -Target "$dn"
		}
	}
	
    Start-Sleep -Seconds 60
	
	$computers = $computerNames.Split(",")
	
	#remotely update GPO policy on PCs and restart PCs, In case of PC is down, wake up PC and remotely update policy.
	foreach ($computer in $computers)
	{
		Start-Job -ArgumentList @($computer, $broadcastAddress, $author, $function, $typ, $idLokalita) -ScriptBlock {
			
			."C:\pcsm_backend\functions_include.ps1"
			$computer = $args[0]
			$broadcastAddress = $args[1]
			$author = $args[2]
			$function = $args[3]
			$typ = $args[4]
            $idlokalita = $args[5]
			
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
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol kontaktovaný a reštartuje sa', 'Režim: $typ', '$author' )"
				}
				else
				{
					$last_check = get-date -format u
					Logger -type "ERROR" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo kontaktovat, WinRM nieje dostupna', 'Režim: $typ', '$author' )"
				}
				
			}
			else
			{
				WakeOnLanPCs -lokalita $idlokalita -computerNames $computer -author $author
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
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol kontaktovaný a reštartuje sa', 'Režim: $typ, Prebehlo budenie systemu', '$author' )"
					}
					else
					{
						$last_check = get-date -format u
						Logger -type "ERROR" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
						MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo kontaktovat', 'Rezim: $typ, Prebehlo budenie systemu', '$author' )"
					}
				}
				else
				{
					$last_check = get-date -format u
					Logger -type "INFO" -text "Na pocitaci $computer sa nepodarilo zmenit rezim..."
					MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Na pocítaci sa nepodarilo zmenit režim', 'Režim: $typ', '$author' )"
				}
			}
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    
}

<#
.SYNOPSIS
checks ancalagon virtual disks
#>

function ancalagonCheck(){
    $status = $true
    $info= "START : " + (get-date -Format "dd.MM.yyyy hh:mm:ss") + "`n"
    1..8 | foreach{
        $name = "\\nfs" + $_ +"\Profiles"
        if((Test-Path -Path $name)){
            $info += "$name is OK`n"
        }else{
            $info += "$name is NOK`n"
            $status = $false
        }

    }
    $info += "END : " + (get-date -Format "dd.MM.yyyy hh:mm:ss") + "`n"
    if($status -eq $false){
        Send-MailMessage -From ancalagon@ics.muni.cz -Body $info -Subject "Cluster failed" -To cuchran@ics.muni.cz -Priority High -SmtpServer relay.muni.cz

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
				WakeOnLanPCs -lokalita $data[0] -computerNames $data[1] -author $author
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END budenie TASK ID $taskId"
			}
			"vypnutie" {
				Logger -type "INFO" -text "START vypinanie TASK ID $taskId"
				ShutdownPCs -lokalita $data[0] -computerNames $data[1] -author $author
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END vypinanie TASK ID $taskId"
			}
			"restart" {
				Logger -type "INFO" -text "START restart TASK ID $taskId"
				RestartPCs -lokalita $data[0] -computerNames $data[1] -author $author
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END restart TASK ID $taskId"
			}
			"rezim" {
				Logger -type "INFO" -text "START rezim TASK ID $taskId"
				ChangeStatePCs -typ $data[0] -lokalita $data[1] -author $author
				MysqlQueryInsert -query "UPDATE fronta SET status='DONE' WHERE id='$taskId'"
				Logger -type "INFO" -text "END rezim TASK ID $taskId"
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
	$fronta = mysqlQuerySelect -query "SELECT * FROM scheduler WHERE  time LIKE '$time%' AND typ='once'"
	$dataTable = new-object System.Data.DataTable
	$dataTable = $fronta.Tables[0]
	
	$dataTable | foreach{
		

		[string]$idlokalita = $_.id_lokalita
		[string]$funkcia = $_.funkcia
		[string]$taskId = $_.id
		[string]$note = $_.note
		[string]$author = $_.author
		
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
				WakeOnLanPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
				Logger -type "INFO" -text "END CHEDULER budenie Scheduler TASK ID $taskId"
			}
			"vypinanie" {
				Logger -type "INFO" -text "START SCHEDULER vypinanie Scheduler TASK ID $taskId"
				ShutdownPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
				Logger -type "INFO" -text "END CHEDULER vypinanie Scheduler TASK ID $taskId"
			}
			"restart" {
				Logger -type "INFO" -text "START SCHEDULER restart Scheduler TASK ID $taskId"
				RestartPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
				Logger -type "INFO" -text "END SCHEDULER restart Scheduler TASK ID $taskId"
			}
			"rezim" {
				Logger -type "INFO" -text "START SCHEDULER rezim Scheduler TASK ID $taskId"
				ChangeStatePCs -lokalita $idlokalita -typ $note -author $author -function "scheduler"
				Logger -type "INFO" -text "END SCHEDULER rezim Scheduler TASK ID $taskId"
			}
			default { }
		}
        #MAIL to CPSADM
            $stopDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            #$operacia = $funkcia
            #$poznamka = $note
            #send-mailmessage -from "PCSM <cuchran@ics.muni.cz>" -to "<cpsadm@ics.muni.cz>" -subject "PCSM - Uskutocnenie planovanej ulohy" -BodyAsHtml -body "V case <b>$startDate - $datum</b> bola na lokalite: <b>$lokalitaName</b> spustena naplanovana operacia: <b>$operacia $poznamka</b>. Log z operacie je dostupny v aplikacii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b><br><br>Tento email je automaticky generovany aplikaciou PCSM." -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
            mailCPS -mailTo "cpsadm@ics.muni.cz" -dateFrom $startDate -dateTo $stopDate -poznamka $note -operacia $funkcia -lokalitaName $lokalitaName -computers $computerNames
        
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
    #ancalagonCheck
	#check queue by time with precision to minute
	$time = Get-Date -Format "HH:mm"
	$fronta = New-Object System.Data.DataSet
	$fronta = mysqlQuerySelect -query "SELECT scheduler.id, scheduler.id_lokalita, scheduler.name, scheduler.typ, scheduler.funkcia, scheduler.author, scheduler_time.id, scheduler.note, scheduler_time.time, scheduler_time.pondelok, scheduler_time.utorok, scheduler_time.streda, scheduler_time.stvrtok, scheduler_time.piatok, scheduler_time.sobota, scheduler_time.nedela, scheduler_time.id_scheduler FROM scheduler INNER JOIN scheduler_time ON scheduler.id=scheduler_time.id_scheduler WHERE scheduler.typ='repeat' AND scheduler_time.time LIKE '$time%'"
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
					WakeOnLanPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
					Logger -type "INFO" -text "END CHEDULER budenie Scheduler TASK ID $taskId"
				}
				"vypinanie" {
					Logger -type "INFO" -text "START SCHEDULER vypinanie Scheduler TASK ID $taskId"
					ShutdownPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
					Logger -type "INFO" -text "END CHEDULER vypinanie Scheduler TASK ID $taskId"
				}
				"restart" {
					Logger -type "INFO" -text "START SCHEDULER restart Scheduler TASK ID $taskId"
					RestartPCs -lokalita $idlokalita -computerNames $computerNames -author $author -function "scheduler"
					Logger -type "INFO" -text "END SCHEDULER restart Scheduler TASK ID $taskId"
				}
				"rezim" {
					Logger -type "INFO" -text "START SCHEDULER rezim Scheduler TASK ID $taskId"
					ChangeStatePCs -lokalita $idlokalita -typ $note -author $author -function "scheduler"
					Logger -type "INFO" -text "END SCHEDULER rezim Scheduler TASK ID $taskId"
				}
				default { }
			}
            #MAIL to CPSADM
            $stopDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            #$operacia = $funkcia
            #$poznamka = $note
            #send-mailmessage -from "PCSM <cuchran@ics.muni.cz>" -to "<cpsadm@ics.muni.cz>" -subject "PCSM - Uskutocnenie planovanej ulohy" -BodyAsHtml -body "V case <b>$startDate - $datum</b> bola na lokalite: <b>$lokalitaName</b> spustena naplanovana operacia: <b>$operacia $poznamka</b>. Log z operacie je dostupny v aplikacii <b>PCSM</b> na <b>ucn-server4.ucn.muni.cz</b><br><br>Tento email je automaticky generovany aplikaciou PCSM." -priority High -dno onSuccess, onFailure -smtpServer relay.muni.cz -Encoding "UTF8"
            mailCPS -mailTo "cpsadm@ics.muni.cz" -dateFrom $startDate -dateTo $stopDate -poznamka $note -operacia $funkcia -lokalitaName $lokalitaName -computers $computerNames
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





