#$filename = Get-Date -format dd_MM_yyyy
#Start-Transcript -Path "C:\pcsm_backend\transcriptLog\$filename.txt" -Append

#DB config
# PCSM database connection string
$connectionString = "server=tali.ics.muni.cz;uid=opsi-reader;pwd=CobDyhenJoc5;database=pcsm;"

# OPSIADMIN database connection string
$connectionStringOpsi = "server=tali.ics.muni.cz;uid=opsi-reader;pwd=CobDyhenJoc5;database=opsiadmin;"

#SETTINGS - variables

# Max WakeUpPings = $wakeUpModulo * $wakeUpMaxMagicPackets, specified for computer wake up
$wakeUpModulo = 10
$wakeUpMaxMagicPackets = 7

# Number of pings during shutdown check
$shutDownPingNumber = 60

<#
.SYNOPSIS
Wake On Lan function.

.DESCRIPTION
Starts PC from down state to up state. Sends magic packet until PC is in up state which is test via cmdlet test-connection (PING).
After $wakeUpModulo pings send magic packet again until number of pings is $wakeUpModulo * $wakeUpMaxMagicPackets.
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
function WakeOnLanPCs
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
        [Parameter(Mandatory = $True, Position = 5)]
		[string]$frontaID
	)
	if ($function -eq "")
	{
		$function = "budenie"
	}
	
	Logger -type "INFO" -text "Lokalita budenia: $lokalita"
	$broadcastAddress = FindBroadcastAddress -lokalita $lokalita
	
	
	$computers = $computerNames.Split(",")
	
	foreach ($computer in $computers)
	{
		
		Start-Job -Name $computer -ArgumentList @($computer, $broadcastAddress, $author, $function, $frontaID) -ScriptBlock {
			
			."C:\pcsm_backend\functions_include.ps1"
			$computer = $args[0]
			$broadcastAddress = $args[1]
			$author = $args[2]
			$function = $args[3]
            $frontaID = $args[4]
			
			$macAddress =findMac($computer)
            
			$last_check = Get-Date -format u
			$first_check = $last_check
			#check if MAC address is correct format
			if ($macAddress -eq $null -or $macAddress -notmatch "(..):(..):(..):(..):(..):(..)")
			{
				Logger -type "ERROR" -text "Nespravna adresa $computer"
				Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo zapnut..."
				MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Nespravna MAC adresa', '', '$author', '$frontaID' )"
				
			}
			else
			{
				Logger -type "INFO" -text "Broadcast IP: $broadcastAddress"
				Logger -type "INFO" -text "Mac Address: $macAddress"

				if(!(Test-Connection -ComputerName $computer -Count 2)){
                    $mac = $macAddress
				    $mac = [byte[]]($matches[1..6] | % { [int]"0x$_" })
				
				    #Create UDP magic Packet
				    $UDPclient = new-Object System.Net.Sockets.UdpClient
				    $UDPclient.Connect($broadcastAddress, 9)
                    $UDPclient_old = new-Object System.Net.Sockets.UdpClient
				    $UDPclient_old.Connect($broadcastAddress, 4000)
				    $packet = [byte[]](, 0xFF * 102)
				    6..101 | % { $packet[$_] = $mac[($_ % 6)] }
				
				    #Send WOL magic Packet to Computer
				    $i = 1;
				    $j = 0;
				    [bool]$stav = $true
				    $first_check = Get-Date -format u
				    while (!(Test-Connection -ComputerName $computer -Count 1))
				    {
					    #check max number of pings
					    if ($j -gt $wakeUpMaxMagicPackets)
					    {
						    $stav = $false
						    break
					    }
					
					    #send WOL magic Packet again
					    if ($i % $wakeUpModulo -eq 1)
					    {
						    $j++
						    $UDPclient.Send($packet, $packet.Length) | out-null
                            $UDPclient_old.Send($packet, $packet.Length) | out-null
						    Logger -type "INFO" -text "Magic Packet odoslany na $computer ..."
					    }
					    $i++
				    }
				
				    $last_check = Get-Date -format u
				    if (!$stav)
				    {
					    Logger -type "ERROR" -text "Pocitac $computer sa nepodarilo zapnut..."
					    MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'FAILED', '$first_check' , '$last_check', 'Pocítac sa nepodarilo zapnút', 'Pocet odoslaných magic paketov je $j', '$author', '$frontaID' )"
				    }
				    else
				    {
					    Logger -type "INFO" -text "Pocitac $computer je zapnuty..."
					    MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac sa podarilo zapnút vo vyhradenom casovom limite', 'Pocet odoslaných magic paketov je $i', '$author', '$frontaID' )"
				    }
                }
                else
                {
                    Logger -type "INFO" -text "Pocitac $computer bol zapnuty pred spustenim skriptu..."
                    MysqlQueryInsert -query "INSERT INTO logs (id, computer_name, process, status, first_check, last_check, note1, note2, author, id_fronta ) VALUES('', '$computer', '$function', 'OK', '$first_check' , '$last_check', 'Pocítac bol zapnuty pred spustenim skriptu', 'Pocet odoslaných magic paketov je 0', '$author', '$frontaID')"
                }
			}
		}
	}
	while ((Get-Job -State Running).count -ne 0)
	{
		Start-Sleep -Seconds 1
	}
    get-job | foreach{
	    $jobFilename = "C:\pcsm_backend\transcriptLog\wake_" + $_.Name + "_" + (get-date -format "yyyy-MM-dd_hh-mm-ss") + ".txt"
	    Receive-Job -Name $_.Name *>> $jobFilename
    }
}

<#
.SYNOPSIS
Create log files with data

.DESCRIPTION
Create log files separatly for every day in \logs\ folder. Format of filename : dd_MM_yyyy_log.txt

.PARAMETER type
Type of log event 

.PARAMETER text
Text which is written into the log file
#>
function Logger
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$type,
		[Parameter(Mandatory = $True, Position = 2)]
		[string]$text
	)
	$date = Get-Date -format dd_MM_yyyy
	$datetime = Get-Date -format u
	$logName = "C:\pcsm_backend\logs\" + $date + "_log.txt"
	echo $logname
	echo "$datetime | $type | $text"
	echo "$datetime | $type | $text" >> $logname
}


<#
.SYNOPSIS
Retrieves data from MySQL opsiadmin databse

.DESCRIPTION
Select query for MySQL opsiadmin databse. In case of failure catch and log exception.

.PARAMETER query
query string for MySQL select
#>
function MysqlQuerySelectFromOpsi
{
	
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$query
	)
	
	try
	{
		
		[void][system.reflection.Assembly]::LoadFrom("C:\pcsm_backend\MySQL.Data.dll")
		$connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$connection.ConnectionString = $connectionStringOpsi
		$connection.Open()
		$sql = $query
		$command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $connection)
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
		
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet)
		$connection.Close()
	}
	Catch
	{
		$connection.Close()
		Logger -type "ERROR" -text "DATABASE OPSIADMIN SELECT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
	}
	
	return $dataSet
}

<#
.SYNOPSIS
Retrieves data from MySQL pcsm database

.DESCRIPTION
Select query for MySQL pcsm databse. In case of failure catch and log exception.

.PARAMETER query
query string for MySQL select
#>
function MysqlQuerySelect
{
	
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$query
	)
	
	try
	{
		
		[void][system.reflection.Assembly]::LoadFrom("C:\pcsm_backend\MySQL.Data.dll")
		$connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$connection.ConnectionString = $connectionString
		$connection.Open()
		$sql = $query
		$command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $connection)
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
		
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet)
		$connection.Close()
	}
	Catch
	{
		$connection.Close()
		Logger -type "ERROR" -text "DATABASE PCSM SELECT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
	}
	
	return $dataSet
}

<#
.SYNOPSIS
Insert data into MySQL pcsm database

.DESCRIPTION
Insert query for MySQL pcsm databse. In case of failure catch and log exception.

.PARAMETER query
query string for MySQL insert
#>

function MysqlQueryInsert
{
	
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$query
	)
	
	try
	{
		[void][system.reflection.Assembly]::LoadFrom("C:\pcsm_backend\MySQL.Data.dll")
		$connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$connection.ConnectionString = $connectionString
		$connection.Open()
		$sql = $query
		$command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $connection)
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet)
	}
	Catch
	{
		$connection.Close()
		Logger -type "ERROR" -text "DATABASE INSERT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
	}
	$connection.Close()
}

<#
.SYNOPSIS
Retrives MAC address of computer

.DESCRIPTION
Retrieves MAC address of computer which is specified as parameter. MAC address is retrieved from opsiadmin database.

.PARAMETER computerName
FQDM of computer
#>
function FindMac
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$computerName
	)
	
	$pc = New-Object System.Data.DataSet
	$pc = MysqlQuerySelectFromOpsi -query "SELECT macAddress,name FROM CLIENTS WHERE name='$computerName' LIMIT 1"
	
    if($pc.Tables[0].macAddress -eq $null){
        $mac =getDhcpMac -computerName $computerName    
    }else{
        $mac =$pc.Tables[0].macAddress 
    }
    return $mac	
}

<#
.SYNOPSIS
Retrieves MAC address from DHCP

.DESCRIPTION
Retrieves MAC address of computer from DHCP reservation.

.PARAMETER computerName
FQDN of computer
#>
function getDhcpMac(){
    
    Param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$computerName	
    )

    $data = $computerName.split('.',2)
    $domain = $data[1]

    switch($domain){
        "ups.ucn.muni.cz" {$serverName = "ups-server1.ups.ucn.muni.cz"}
        "staff.ucn.muni.cz" {$serverName = "staff-server1.staff.ucn.muni.cz"}
        "phill.ucn.muni.cz" {$serverName = "phill-server1.staff.ucn.muni.cz"}
        "zam.ucn.muni.cz" {$serverName = "zam-server1.staff.ucn.muni.cz"}
        "law.ucn.muni.cz" {$serverName = "law-server1.staff.ucn.muni.cz"}
        "fss.ucn.muni.cz" {$serverName = "fss-server1.staff.ucn.muni.cz"}
    }

    $scopes = Get-DhcpServerv4Scope -ComputerName $serverName | select ScopeId

    [string]$mac=""
    $scopes | foreach{
        $scopeReservations = Get-DhcpServerv4Reservation -ComputerName $serverName -ScopeId $_.ScopeId   
        $scopeReservations | foreach{
            if($_.Name -eq $computerName){
                    $mac = $_.ClientId
            }
        }  
    }
    $mac=$mac -replace "-", ":"  
    return $mac
}

<#
.SYNOPSIS
Retrieves broadcast address of locality

.DESCRIPTION
Retrieves broadcast IP address of locality which is specified as parameter.

.PARAMETER lokalita
ID of locality
#>

function FindBroadcastAddress
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$lokalita
	)
	
	$pc = New-Object System.Data.DataSet
	$pc = MysqlQuerySelect -query "SELECT broadcast FROM lokality WHERE id='$lokalita' LIMIT 1"
	
	return $pc.Tables[0].broadcast
	
}

<#
.SYNOPSIS
Returns distinguished name of locality

.DESCRIPTION
Returns distinguished name of locality specified as paramter from pcsm database
.PARAMETER idlokalita
ID locality
#>

function FindLokalitaOu
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$idlokalita
	)
	
	$pc = New-Object System.Data.DataSet
	$pc = MysqlQuerySelect -query "SELECT dn FROM lokality WHERE id='$idlokalita' LIMIT 1"
	
	return $pc.Tables[0].dn
	
}