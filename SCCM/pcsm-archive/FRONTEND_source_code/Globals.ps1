#--------------------------------------------
# Declare Global Variables and Functions here
#--------------------------------------------

$launcherProcessID = -1


$author = [Environment]::UserName

$filterName = ""
$filterStatus = ""
#$filterOd = (Get-Date -Format "yyyy-MM-dd").ToString() #"0000-00-00"
$filterOd = "2003-00-00"
$filterDo = "2048-00-00"
$sqlLimit = 1000
[string]$sqlQuery = "Zatial nebol uskutočnený žiaden SQL dotaz"


# Profile reset	timeout
$checkProfileTimeout = 50000

# Irkala CPS restart timeout
$checkIrkalaTimeout = 12000


#LDAP settings | ucn-server1 or ucn-server2
$domainControler = "ucn-server1.ucn.muni.cz"

	if (Test-Connection -Count 1 -ComputerName "ucn-server1.ucn.muni.cz")
	{
		$domainControler = "ucn-server1.ucn.muni.cz"
	}
	else
	{
		$domainControler = "ucn-server0.ucn.muni.cz"
	}

#connection string for database pcsm
$connectionString = "server=tali.ics.muni.cz;uid=opsi-reader;pwd=CobDyhenJoc5;database=pcsm;"

#Function that provides the location of the script
function Get-ScriptDirectory
{ 
	if($hostinvocation -ne $null)
	{
		Split-Path $hostinvocation.MyCommand.path
	}
	else
	{
		Split-Path $script:MyInvocation.MyCommand.Path
	}
}

<#
.SYNOPSIS
Checks user permissions by name and function

.DESCRIPTION
Checks user permissions by ucn username and aplication function

.PARAMETER name
UCN username

.PARAMETER function
Application function
#>
function checkPermission()
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$name,
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$function
	)
	
	$prava = $false
	try
	{
		$sql_string = "name='" + $name + "'"
		Get-ADPrincipalGroupMembership -Identity $name -server $domainControler | ForEach-Object{
			$sql_string += " OR name='" + $_.name + "'"
		}
		$fronta = New-Object System.Data.DataSet
		$fronta = MysqlQuerySelect -query "SELECT * FROM acl WHERE ($sql_string) AND funkcia='$function' GROUP BY funkcia"
		if ($fronta.Tables[0].rows.count -eq 0)
		{
			$prava = $false
		}
		else
		{
			$prava = $true
		}
	}
	Catch
	{
		#[System.Windows.Forms.MessageBox]::Show("Nepodarilo sa pripojiť k doménovému radiču. Nieje možné overiť vaše oprávnenia")
		Logger -type "ERROR" -text "DOMAIN CONTROLER ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
		$prava = $false
		if ([System.Windows.Forms.MessageBox]::Show("Nepodarilo sa pripojiť k doménovému radiču. Nieje možné overiť vaše oprávnenia") -eq "OK")
		{
			
			$MainForm.Close()
			$global:ExitCode = 0
			break
		}
	}
	return $prava
}


<#
.SYNOPSIS
Checks if user is admin, member of UCNadmins

.DESCRIPTION
Checks if user is admin, member of UCNadmins

.PARAMETER name
UCN username
#>
function checkAdminPermission()
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$name
	)
	$admin = $false
	try
	{	
		Get-ADPrincipalGroupMembership -Identity $name -server $domainControler | ForEach-Object{
			if ($_.name -match "UCNAdmins")
			{
				$admin =  $true
			}
		}
	}
	Catch
	{
		#[System.Windows.Forms.MessageBox]::Show("Nepodarilo sa pripojiť k doménovému radiču. Nieje možné overiť vaše oprávnenia")
		Logger -type "ERROR" -text "DOMAIN CONTROLER ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
		$admin = $false
		
		if ([System.Windows.Forms.MessageBox]::Show("Nepodarilo sa pripojiť k doménovému radiču. Nieje možné overiť vaše oprávnenia") -eq "OK")
		{
			
			$MainForm.Close()
			$global:ExitCode = 0
			break
		}
		
	}
	return $admin
}



<#
.SYNOPSIS
Create log files with data from app

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
	$dattime = Get-Date -format u
	$logName ="logs\" + $date + "_log.txt"
	echo $logname
	echo "$dattime | $type | $text"
	echo "$dattime | $type | $text" >> $logname
}


function MysqlLogger()
{
	param (
		[Parameter(Mandatory = $True, Position = 1)]
		[string]$sql_query
	)
	
	try
	{
		[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
		$connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$connection.ConnectionString = $connectionString
		$connection.Open()
		$sql_query_write=$sql_query.Replace("'","")
		$sql = "INSERT INTO application_log (id,author,sql_query) VALUES('','$author','$sql_query_write')"
		$command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $connection)
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet)
	}
	Catch
	{
		Logger -type "ERROR" -text "DATABASE SELECT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
		if([System.Windows.Forms.MessageBox]::Show("Pri práci s databázou sa vyskytla kritická chyba. Zobrazované dáta môžu byť nekompletné. `n $logException ") -eq "OK")
		{
			$connection.Close()
			$MainForm.Close()
			$global:ExitCode = 0
			break
			
		}
		
	}
	$connection.Close()
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
		[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
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
		Logger -type "ERROR" -text "DATABASE SELECT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
		if([System.Windows.Forms.MessageBox]::Show("Pri práci s databázou sa vyskytla kritická chyba. Zobrazované dáta môžu byť nekompletné. `n $logException ") -eq "OK")
		{
			$connection.Close()
			$MainForm.Close()
			$global:ExitCode = 0
			break
			
		}
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
		[void][System.Reflection.Assembly]::LoadWithPartialName("MySql.Data")
		$connection = New-Object MySql.Data.MySqlClient.MySqlConnection
		$connection.ConnectionString = $connectionString
		$connection.Open()
		$sql = $query
		$command = New-Object MySql.Data.MySqlClient.MySqlCommand($sql, $connection)
		$dataAdapter = New-Object MySql.Data.MySqlClient.MySqlDataAdapter($command)
		$dataSet = New-Object System.Data.DataSet
		$recordCount = $dataAdapter.Fill($dataSet)
		MysqlLogger -sql_query $query
	}
	Catch
	{
		Logger -type "ERROR" -text "DATABASE SELECT ERROR"
		$logException = $_.Exception.GetType().FullName;
		$logException += $_.Exception.Message;
		Logger -type "ERROR" -text $logException
		if([System.Windows.Forms.MessageBox]::Show("Pri práci s databázou sa vyskytla kritická chyba. Zobrazované dáta môžu byť nekompletné. `n $logException ") -eq "OK")
		{
			$connection.Close()
			$MainForm.Close()
			$global:ExitCode = 0
			break
			
		}
	}
	$connection.Close()
}

#Variable that provides the location of the script
[string]$ScriptDirectory = Get-ScriptDirectory



function Load-ComboBox
{
<#
	.SYNOPSIS
		This functions helps you load items into a ComboBox.

	.DESCRIPTION
		Use this function to dynamically load items into the ComboBox control.

	.PARAMETER  ComboBox
		The ComboBox control you want to add items to.

	.PARAMETER  Items
		The object or objects you wish to load into the ComboBox's Items collection.

	.PARAMETER  DisplayMember
		Indicates the property to display for the items in this control.
	
	.PARAMETER  Append
		Adds the item(s) to the ComboBox without clearing the Items collection.
	
	.EXAMPLE
		Load-ComboBox $combobox1 "Red", "White", "Blue"
	
	.EXAMPLE
		Load-ComboBox $combobox1 "Red" -Append
		Load-ComboBox $combobox1 "White" -Append
		Load-ComboBox $combobox1 "Blue" -Append
	
	.EXAMPLE
		Load-ComboBox $combobox1 (Get-Process) "ProcessName"
#>
	Param (
		[ValidateNotNull()]
		[Parameter(Mandatory = $true)]
		[System.Windows.Forms.ComboBox]$ComboBox,
		[ValidateNotNull()]
		[Parameter(Mandatory = $true)]
		$Items,
		[Parameter(Mandatory = $false)]
		[string]$DisplayMember,
		[switch]$Append
	)
	
	if (-not $Append)
	{
		$ComboBox.Items.Clear()
	}
	
	if ($Items -is [Object[]])
	{
		$ComboBox.Items.AddRange($Items)
	}
	elseif ($Items -is [Array])
	{
		$ComboBox.BeginUpdate()
		foreach ($obj in $Items)
		{
			$ComboBox.Items.Add($obj)
		}
		$ComboBox.EndUpdate()
	}
	else
	{
		$ComboBox.Items.Add($Items)
	}
	
	$ComboBox.DisplayMember = $DisplayMember
}

