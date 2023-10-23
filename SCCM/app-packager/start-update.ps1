<#
	.NOTES
	===========================================================================
	 Created on:   	1/9/2018 11:34 AM
	 Author:		Adrian Rosinec, Andrew Jimenez (asjimene) - https://github.com/asjimene/
	 Filename:     	start-update.ps1
	===========================================================================
	.DESCRIPTION
		Packages Applications for SCCM using XML Based Recipe Files

	Uses Scripts and Functions Sourced from the Following:
		Copy-CMDeploymentTypeRule - https://janikvonrotz.ch/2017/10/20/configuration-manager-configure-requirement-rules-for-deployment-types-with-powershell/
		Get-ExtensionAttribute - Jaap Brasser - http://www.jaapbrasser.com
		Get-MSIInfo - Nickolaj Andersen - http://www.scconfigmgr.com/2014/08/22/how-to-get-msi-file-information-with-powershell/
	.PARAMETER Team 
		Available values are demo/prod, choosing information channel - this is just for testing purposes or manual run.
	.PARAMETER Unattend
		Run script with unattend parameter for automatic updates
	.PARAMETER Mailer
		Like parameter Team - but handles whenever to send or do not send an email message.
	.EXAMPLE 
	.\start-udate-ps1 -Team "prod" -Mailer
	
	Description
	-----------
	Runs Updater in normal mode (with question)
	.EXAMPLE 
	.\start-udate-ps1 -Team "prod" -Mailer -unattend

	Description
	-----------
	Use for automatic updates.
#>

## Global parameters needed to run in Unattend mode.
param(
	[string]$Team = "demo",
	[switch]$Unattend = $False,
	[switch]$Mailer
)

$Global:ScriptRoot = $PSScriptRoot

## Global Variables
# Import the Prefs file
[xml]$PackagerPrefs = Get-Content $ScriptRoot\SCCMPackager.prefs

# Packager Vars
$Global:TempDir = $PackagerPrefs.PackagerPrefs.TempDir

# Logs
$Global:LogPath = $PackagerPrefs.PackagerPrefs.LogPath
$Global:ErrorLogFile = Join-Path $Global:LogPath "error_log-$(Get-Date -Format yyyy-MM-dd).log"
$Global:LogFile = Join-Path $Global:LogPath "log-$(Get-date -Format yyyy-MM-dd).log"

# Package Location Vars
$Global:ContentLocationRoot = $PackagerPrefs.PackagerPrefs.ContentLocationRoot
$Global:IconRepo = $PackagerPrefs.PackagerPrefs.IconRepo

# SCCM Vars
$Global:SCCMSite = $PackagerPrefs.PackagerPrefs.SCCMSite
$Global:SCCMAccount = $PackagerPrefs.PackagerPrefs.SCCMAccount
$Global:RequirementsTemplateAppName = $PackagerPrefs.PackagerPrefs.RequirementsTemplateAppName
$Global:PreferredDistributionLoc = $PackagerPrefs.PackagerPrefs.PreferredDistributionLoc

# Software Maintanace Vars
$Global:AppRotateKeep = $PackagerPrefs.PackagerPrefs.AppRotateKeep


# Email Vars
[string[]]$Global:EmailToPROD = [string[]]$PackagerPrefs.PackagerPrefs.EmailToPROD
[string[]]$Global:EmailToTEST = [string[]]$PackagerPrefs.PackagerPrefs.EmailToTEST.split(',')
[string[]]$Global:EmailToAdmins = [string[]]$PackagerPrefs.PackagerPrefs.EmailToAdmins.split(',')
$Global:EmailFrom = $PackagerPrefs.PackagerPrefs.EmailFrom
$Global:EmailServer = $PackagerPrefs.PackagerPrefs.EmailServer
$Global:SendEmailPreference = [System.Convert]::ToBoolean($PackagerPrefs.PackagerPrefs.SendEmailPreference)
$Global:NotifyOnDownloadFailure = [System.Convert]::ToBoolean($PackagerPrefs.PackagerPrefs.NotifyOnDownloadFailure)
$Global:NextMailFilePath = "$Global:ScriptRoot\next_mail.txt"

$Global:EmailSubject = "Aktualizacie Softwaru - $(get-date -UFormat '%d.%m.%Y')"
$Global:EmailBody = ""

#This gets switched to True if Applications are Packaged
$Global:SendEmail = $false

# Task Sequence for software installation
$Global:SoftwareTaskSequenceName = "Software Installation"

## Functions

function Add-LogContent {
	param
	(
		[parameter(Mandatory = $true)]
		$Content,
		[parameter(Mandatory = $false)]
		[switch]$Load = $False,
		[parameter(Mandatory = $false)]
		[ValidateSet("Error", "Info")]
		[string]$Level = "Info",
		[switch]$ForceError
	)
	

#Set-Location -Path $Global:ScriptRoot

	# Build content
	$message = ""
	#Date and time
	$message += "$(Get-Date -Format G) - "
	#Header 
	$message += "[$Level] - "
	#Content
	$message += $Content
	#Done

	if ($Load) {
		New-Item -Path $Global:LogFile -Force
		New-Item -Path $Global:ErrorLogFile -Force
	}

	switch ($Level) {
		'Error' {
			# Error goes to both files.
			$message >> $Global:LogFile
			$message >> $Global:ErrorLogFile
		}
		'Info' {
			if ($ForceError){
				$message >> $Global:ErrorLogFile
			}
			# Info only to log file.
			$message >> $Global:LogFile
		}
	}

	#Set-Location -Path $Global:SCCMSite
}
Function Get-RedirectedUrl {

    Param (
        [Parameter(Mandatory=$true)]
        [String]$URL
    )

    $request = [System.Net.WebRequest]::Create($url)
    $request.AllowAutoRedirect=$false
    $response=$request.GetResponse()

    If ($response.StatusCode -eq "Found")
    {
        $response.GetResponseHeader("Location")
    }
}
function Get-ExtensionAttribute {
<#
.Synopsis
Retrieves extension attributes from files or folder

.DESCRIPTION
Uses the dynamically generated parameter -ExtensionAttribute to select one or multiple extension attributes and display the attribute(s) along with the FullName attribute

.NOTES
Name: Get-ExtensionAttribute.ps1
Author: Jaap Brasser
Version: 1.0
DateCreated: 2015-03-30
DateUpdated: 2015-03-30
Blog: http://www.jaapbrasser.com

.LINK
http://www.jaapbrasser.com

.PARAMETER FullName
The path to the file or folder of which the attributes should be retrieved. Can take input from pipeline and multiple values are accepted.

.PARAMETER ExtensionAttribute
Additional values to be loaded from the registry. Can contain a string or an array of string that will be attempted to retrieve from the registry for each program entry

.EXAMPLE
. .\Get-ExtensionAttribute.ps1

Description
-----------
This command dot sources the script to ensure the Get-ExtensionAttribute function is available in your current PowerShell session

.EXAMPLE
Get-ExtensionAttribute -FullName C:\Music -ExtensionAttribute Size,Length,Bitrate

Description
-----------
Retrieves the Size,Length,Bitrate and FullName of the contents of the C:\Music folder, non recursively

.EXAMPLE
Get-ExtensionAttribute -FullName C:\Music\Song2.mp3,C:\Music\Song.mp3 -ExtensionAttribute Size,Length,Bitrate

Description
-----------
Retrieves the Size,Length,Bitrate and FullName of Song.mp3 and Song2.mp3 in the C:\Music folder

.EXAMPLE
Get-ChildItem -Recurse C:\Video | Get-ExtensionAttribute -ExtensionAttribute Size,Length,Bitrate,Totalbitrate

Description
-----------
Uses the Get-ChildItem cmdlet to provide input to the Get-ExtensionAttribute function and retrieves selected attributes for the C:\Videos folder recursively

.EXAMPLE
Get-ChildItem -Recurse C:\Music | Select-Object FullName,Length,@{Name = 'Bitrate' ; Expression = { Get-ExtensionAttribute -FullName $_.FullName -ExtensionAttribute Bitrate | Select-Object -ExpandProperty Bitrate } }

Description
-----------
Combines the output from Get-ChildItem with the Get-ExtensionAttribute function, selecting the FullName and Length properties from Get-ChildItem with the ExtensionAttribute Bitrate
#>
	[CmdletBinding()]
	Param (
		[Parameter(ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0)]
		[string[]]$FullName
	)
	DynamicParam {
		$Attributes = new-object System.Management.Automation.ParameterAttribute
		$Attributes.ParameterSetName = "__AllParameterSets"
		$Attributes.Mandatory = $false
		$AttributeCollection = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
		$AttributeCollection.Add($Attributes)
		$Values = @($Com = (New-Object -ComObject Shell.Application).NameSpace('C:\'); 1 .. 400 | ForEach-Object { $com.GetDetailsOf($com.Items, $_) } | Where-Object { $_ } | ForEach-Object { $_ -replace '\s' })
		$AttributeValues = New-Object System.Management.Automation.ValidateSetAttribute($Values)
		$AttributeCollection.Add($AttributeValues)
		$DynParam1 = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("ExtensionAttribute", [string[]], $AttributeCollection)
		$ParamDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
		$ParamDictionary.Add("ExtensionAttribute", $DynParam1)
		$ParamDictionary
	}

	begin {
		$ShellObject = New-Object -ComObject Shell.Application
		$DefaultName = $ShellObject.NameSpace('C:\')
		$ExtList = 0 .. 400 | ForEach-Object {
			($DefaultName.GetDetailsOf($DefaultName.Items, $_)).ToUpper().Replace(' ', '')
		}
	}

	process {
		foreach ($Object in $FullName) {
			# Check if there is a fullname attribute, in case pipeline from Get-ChildItem is used
			if ($Object.FullName) {
				$Object = $Object.FullName
			}

			# Check if the path is a single file or a folder
			if (-not (Test-Path -Path $Object -PathType Container)) {
				$CurrentNameSpace = $ShellObject.NameSpace($(Split-Path -Path $Object))
				$CurrentNameSpace.Items() | Where-Object {
					$_.Path -eq $Object
				} | ForEach-Object {
					$HashProperties = @{
						FullName	 = $_.Path
					}
					foreach ($Attribute in $MyInvocation.BoundParameters.ExtensionAttribute) {
						$HashProperties.$($Attribute) = $CurrentNameSpace.GetDetailsOf($_, $($ExtList.IndexOf($Attribute.ToUpper())))
					}
					New-Object -TypeName PSCustomObject -Property $HashProperties
				}
			}
			elseif (-not $input) {
				$CurrentNameSpace = $ShellObject.NameSpace($Object)
				$CurrentNameSpace.Items() | ForEach-Object {
					$HashProperties = @{
						FullName	 = $_.Path
					}
					foreach ($Attribute in $MyInvocation.BoundParameters.ExtensionAttribute) {
						$HashProperties.$($Attribute) = $CurrentNameSpace.GetDetailsOf($_, $($ExtList.IndexOf($Attribute.ToUpper())))
					}
					New-Object -TypeName PSCustomObject -Property $HashProperties
				}
			}
		}
	}

	end {
		Remove-Variable -Force -Name DefaultName
		Remove-Variable -Force -Name CurrentNameSpace
		Remove-Variable -Force -Name ShellObject
	}
}

function Get-MSIInfo {
	param (
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[System.IO.FileInfo]$Path,
		[parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[ValidateSet("ProductCode", "ProductVersion", "ProductName", "Manufacturer", "ProductLanguage", "FullVersion")]
		[string]$Property
	)

	Process {
		try {
			# Read property from MSI database
			$WindowsInstaller = New-Object -ComObject WindowsInstaller.Installer
			$MSIDatabase = $WindowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $WindowsInstaller, @($Path.FullName, 0))
			$Query = "SELECT Value FROM Property WHERE Property = '$($Property)'"
			$View = $MSIDatabase.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $MSIDatabase, ($Query))
			$View.GetType().InvokeMember("Execute", "InvokeMethod", $null, $View, $null)
			$Record = $View.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $View, $null)
			$Value = $Record.GetType().InvokeMember("StringData", "GetProperty", $null, $Record, 1)

			# Commit database and close view
			$MSIDatabase.GetType().InvokeMember("Commit", "InvokeMethod", $null, $MSIDatabase, $null)
			$View.GetType().InvokeMember("Close", "InvokeMethod", $null, $View, $null)
			$MSIDatabase = $null
			$View = $null

			# Return the value
			return $Value
		}
		catch {
			Write-Warning -Message $_.Exception.Message; break
		}
	}
	End {
		# Run garbage collection and release ComObject
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject($WindowsInstaller) | Out-Null
		[System.GC]::Collect()
	}
}

Function Download-Application {
	Param (
		$Recipe
	)
	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	$NewApp = $false

	ForEach ($Download In $Recipe.ApplicationDef.Downloads.ChildNodes) {
		## Set Variables
		$DownloadFileName = $Download.DownloadFileName
		$URL = $Download.URL
		$DownloadVersionCheck = $Download.DownloadVersionCheck
		$DownloadFile = "$TempDir\$DownloadFileName"
		$AppRepoFolder = $Download.AppRepoFolder
		$ExtraCopyFunctions = $Download.ExtraCopyFunctions

		## Run the prefetch script if it exists
		$PrefetchScript = $Download.PrefetchScript
		If (-not ([String]::IsNullOrEmpty($PrefetchScript))) {
			Invoke-Expression $PrefetchScript | Out-Null
		}

		## Download the Application
		If (-not ([String]::IsNullOrEmpty($URL))) {
			Add-LogContent "[Download] Downloading $ApplicationName from $URL"
			$ProgressPreference = 'SilentlyContinue'
			try {
				(New-Object System.Net.WebClient).DownloadFile($URL, $DownloadFile)
			} catch {
				$ErrorMessage = $_.Exception.Message
				$FullyQualified = $_.FullyQualifiedErrorID
				Add-LogContent "[Download] Error while downloading $ApplicationName from $URL." -Level "Error"
				Add-LogContent "[Download] ERROR: $ErrorMessage" -Level "Error"
				Add-LogContent "[Download] ERROR: $FullyQualified" -Level "Error"
				Add-LogContent "[Download] ERROR: $($_.CategoryInfo.Category): $($_.CategoryInfo.Reason)" -Level "Error"
				# Stop packaging progress on download error.
				return $NewApp
			}
			Add-LogContent "[Download] Completed Downloading $ApplicationName"
		} else {
            Add-LogContent "[Download] URL Not Specified, Skipping Download."
        }


		## Run the Version Check Script and record the Version and FullVersion
		If (-not ([String]::IsNullOrEmpty($DownloadVersionCheck))) {
			Invoke-Expression $DownloadVersionCheck | Out-Null
		}
		$Download.Version = [string]$Version
		$Download.FullVersion = [string]$FullVersion
		$ApplicationSWVersion = $Download.Version
		Add-LogContent "[Download] Found Version $ApplicationSWVersion from Download FullVersion: $FullVersion"

        ## Determine if the Download Failed or if an Application Version was not detected, and add the Failure to the email if the Flag is set
        if ((-not (Test-Path $DownloadFile)) -or ([System.String]::IsNullOrEmpty($ApplicationSWVersion))) {
            Add-LogContent "[Download] ERROR: Failed to Download or find the Version for $ApplicationName"
            if ($Global:NotifyOnDownloadFailure) {
                $Global:SendEmail = $True
                $Global:EmailBody += "   - Failed to Download: $ApplicationName`n"
            }
        }

		## Contact SCCM and determine if the Application Version is New
		Push-Location
		Set-Location $Global:SCCMSite
		If ((-not (Get-CMApplication -Name "$ApplicationName $ApplicationSWVersion" -Fast)) -and (-not ([System.String]::IsNullOrEmpty($ApplicationSWVersion)))) {
            $NewApp = $true
            Add-LogContent "[Download] $ApplicationSWVersion is a new Version"
		}
		Else {
            $NewApp = $false
			Add-LogContent "[Download] $ApplicationSWVersion is not a new Version - Moving to next application"
		}
		Pop-Location


		## Create the Application folders and copy the download if the Application is New
		If ($NewApp) {
			## Create Application Share Folder
			If ([String]::IsNullOrEmpty($AppRepoFolder)) {
				$DestinationPath = "$Global:ContentLocationRoot\$ApplicationName\Packages\$Version"
				Add-LogContent "[Download] Destination Path set as $DestinationPath"
			}
			Else {
				$DestinationPath = "$Global:ContentLocationRoot\$ApplicationName\Packages\$Version\$AppRepoFolder"
				Add-LogContent "[Download] Destination Path set as $DestinationPath"
			}
			New-Item -ItemType Directory -Path $DestinationPath -Force

			## Copy to Download to Application Share
			Add-LogContent "[Download] Copying installation files to $DestinationPath"
			Copy-Item -Path $DownloadFile -Destination $DestinationPath -Force

			## Copy Addons to folder with exe
			if(Test-Path "$ScriptRoot\Extra\$ApplicationName"){
				try {
					Copy-Item -Path "$ScriptRoot\Extra\$ApplicationName\*" -Destination $DestinationPath -Recurse -Force
					Add-LogContent "[Download] Additional content coppied to application files."
				} catch {
					Add-LogContent "[Download] Additional content to copy wasn't found."
				}
			}

			## Extra Copy Functions If Required
			If (-not ([String]::IsNullOrEmpty($ExtraCopyFunctions))) {
				Add-LogContent "[Download] Performing Extra Copy Functions"
				Invoke-Expression $ExtraCopyFunctions | Out-Null
			}
		}
	}

	## Return True if All Downloaded Applications were new Versions
	Return $NewApp
}

<#
.SYNOPSIS
Returns name of the application if creating was successful operation, false otherwise

.DESCRIPTION
Creates application from Recipe

.PARAMETER Recipe
$Recipe

.NOTES
General notes
#>
Function Create-Application {
	Param (
		$Recipe
	)

	## Set Variables
	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	$ApplicationPublisher = $Recipe.ApplicationDef.Application.Publisher
	$ApplicationDescription = $Recipe.ApplicationDef.Application.Description
	$ApplicationDocURL = $Recipe.ApplicationDef.Application.UserDocumentation
	$ApplicationIcon = "$Global:IconRepo\$($Recipe.ApplicationDef.Application.Icon)"
	$ApplicationAutoInstall = [System.Convert]::ToBoolean($Recipe.ApplicationDef.Application.AutoInstall)


	ForEach ($Download In ($Recipe.ApplicationDef.Downloads.Download)) {
		If (-not ([System.String]::IsNullOrEmpty($Download.Version))) {
			$ApplicationSWVersion = $Download.Version
		}
	}

	$AppCreated = $true

	## Create the Application
	Push-Location
	Set-Location $Global:SCCMSite
	Add-LogContent "[Create Application] Creating Application: $ApplicationName $ApplicationSWVersion"

	$AppExists = Get-CMApplication -ApplicationName "$ApplicationName $ApplicationSWVersion"
	if (-not ([System.String]::IsNullOrEmpty($AppExists))) {
		Add-LogContent "[Create Application] Application '$ApplicationName $ApplicationSWVersion' exists. Skipping."
		$AppCreated = $false
		pop-Location
		return $AppCreated
	}

	Try {
		If ($ApplicationIcon -ne "$Global:IconRepo\") {
			Add-LogContent "[Create Application] Creating AppPackage with Icon."
			Add-LogContent "Command: New-CMApplication -Name $ApplicationName $ApplicationSWVersion -Description $ApplicationDescription -Publisher $ApplicationPublisher -SoftwareVersion $ApplicationSWVersion -OptionalReference $ApplicationDocURL -AutoInstall $ApplicationAutoInstall -ReleaseDate (Get-Date) -LocalizedName $ApplicationName $ApplicationSWVersion -LocalizedDescription $ApplicationDescription -UserDocumentation $ApplicationDocURL -IconLocationFile $ApplicationIcon"
			New-CMApplication -Name "$ApplicationName $ApplicationSWVersion" -Description $ApplicationDescription -Publisher "$ApplicationPublisher" -SoftwareVersion $ApplicationSWVersion -OptionalReference $ApplicationDocURL -AutoInstall $ApplicationAutoInstall -ReleaseDate (Get-Date) -LocalizedName "$ApplicationName" -LocalizedDescription $ApplicationDescription -UserDocumentation $ApplicationDocURL -IconLocationFile $ApplicationIcon | Out-Null
		}
		Else {
			Add-LogContent "[Create Application] Creating AppPackage without Icon - Maybe doesn't exist?"
            Add-LogContent "Command: New-CMApplication -Name $ApplicationName $ApplicationSWVersion -Description $ApplicationDescription -Publisher $ApplicationPublisher -SoftwareVersion $ApplicationSWVersion -OptionalReference $ApplicationDocURL -AutoInstall $ApplicationAutoInstall -ReleaseDate (Get-Date) -LocalizedName $ApplicationName $ApplicationSWVersion -LocalizedDescription $ApplicationDescription -UserDocumentation"
			New-CMApplication -Name "$ApplicationName $ApplicationSWVersion" -Description $ApplicationDescription -Publisher "$ApplicationPublisher" -SoftwareVersion $ApplicationSWVersion -OptionalReference $ApplicationDocURL -AutoInstall $ApplicationAutoInstall -ReleaseDate (Get-Date) -LocalizedName "$ApplicationName" -LocalizedDescription $ApplicationDescription -UserDocumentation $ApplicationDocURL | Out-Null
		}
	}
	Catch {
		$AppCreated = $false
		$ErrorMessage = $_.Exception.Message
		$FullyQualified = $_.FullyQualifiedErrorID
		Add-LogContent "[Create Application] ERROR: $ApplicationName $ApplicationSWVersion - Creation Failed!" -Level "Error"
		Add-LogContent "[Create Application] ERROR: $ErrorMessage" -Level "Error"
		Add-LogContent "[Create Application] ERROR: $FullyQualified" -Level "Error"
		Add-LogContent "[Create Application] ERROR: $($_.CategoryInfo.Category): $($_.CategoryInfo.Reason)" -Level "Error"
	}
	
	## Send an Email if an Application was successfully Created.
	If ($AppCreated){
		$Global:SendEmail = $true
		Rotate-Applications -ApplicationName $ApplicationName -ApplicationVersion $ApplicationSWVersion
	}

	Pop-Location

	## Return True if the Application was Created Successfully
	Return $AppCreated, $ApplicationName, $ApplicationSWVersion
}

<#
.SYNOPSIS
Removes oldest application if new one was created.

.DESCRIPTION
Similar to generaly known Log Rotation functions

.PARAMETER Recipe
$Recipe
#>
Function Rotate-Applications {
	Param (
		$ApplicationName,
		$ApplicationVersion
	)
	Push-Location
	Set-Location $Global:SCCMSite

	try {
		$AllVersions = Get-CMApplication -Fast | Where-Object {$_.LocalizedDisplayName -Match [regex]::Escape($ApplicationName) -and $_.SoftwareVersion -ne $ApplicationVersion} | Select-Object SoftwareVersion
		$oldVersions = ($AllVersions | ForEach-Object { [System.Version]$_.SoftwareVersion } | Sort-Object -Descending) | Select-Object -skip ($Global:AppRotateKeep - 1)
		
		if ($oldVersions.Length -gt 0) {
			Add-LogContent "[App Rotate] For $ApplicationName I have found $($oldVersions.Length) older versions."
		} else {
			Add-LogContent "[App Rotate] For $ApplicationName I haven't found any older version. Skipping..."
			Pop-Location
			return
		}

		foreach ($oldVersion in $oldVersions) {
			$NameVersion = "$ApplicationName $oldVersion"
			$removingApp = Get-CMApplication -ApplicationName $NameVersion
			Add-LogContent "[App Rotate] Removing version: $oldVersion."
			Get-CMDeployment -SoftwareName $removingApp.LocalizedDisplayName -FeatureType "Application" | Remove-CMDeployment -Force
			$removingApp | Remove-CMApplication -Force
		}
	} catch {
		$ErrorMessage = $_.Exception.Message
		$FullyQualified = $_.Exeption.FullyQualifiedErrorID
		Add-LogContent "[App Rotate] ERROR: Could not remove any older applications for: $ApplicationName $ApplicationVersion." -Level "Error"
		Add-LogContent "[App Rotate] ERROR: $ErrorMessage" -Level "Error"
		Add-LogContent "[App Rotate] ERROR: $FullyQualified" -Level "Error"
	}

	Pop-Location
}

Function Add-DetectionMethodClause {
	Param (
		$DetectionMethod,
		$AppVersion,
		$AppFullVersion
	)

	$detMethodDetectionClauseType = $DetectionMethod.DetectionClauseType
	Add-LogContent "[Detection] Adding Detection Method Clause Type $detMethodDetectionClauseType"
	Switch ($detMethodDetectionClauseType) {
		Directory {
			$detMethodCommand = "New-CMDetectionClauseDirectory"
			If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Name))) {
				$detMethodCommand += " -DirectoryName `'$($DetectionMethod.Name)`'"
			}
		}
		File {
			$detMethodCommand = "New-CMDetectionClauseFile"
			If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Name))) {
				$detMethodCommand += " -FileName `'$($DetectionMethod.Name)`'"
			}
		}
		RegistryKey {
			$detMethodCommand = "New-CMDetectionClauseRegistryKey"
		}
		RegistryKeyValue {
			$detMethodCommand = "New-CMDetectionClauseRegistryKeyValue"

		}
		WindowsInstaller {
			$detMethodCommand = "New-CMDetectionClauseWindowsInstaller"
		}
	}
	If (([System.Convert]::ToBoolean($DetectionMethod.Existence)) -and (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Existence)))) {
		$detMethodCommand += " -Existence"
	}
	If (([System.Convert]::ToBoolean($DetectionMethod.Is64Bit)) -and (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Is64Bit)))) {
		$detMethodCommand += " -Is64Bit"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Path))) {
		If ($DetectionMethod.Path -like "*`$Version*") {
			Add-LogContent "[Detection] Replacing `$Version in $($DetectionMethod.Path)"
			$DetectionMethod.Path = ($DetectionMethod.Path).Replace('$Version', $AppVersion)
		}
		If ($DetectionMethod.Path -like "*`$FullVersion*") {
			Add-LogContent "[Detection] Replacing `$FullVersion in $($DetectionMethod.Path)"
			$DetectionMethod.Path = ($DetectionMethod.Path).Replace('$FullVersion', $AppFullVersion)
		}
		$detMethodCommand += " -Path `'$($DetectionMethod.Path)`'"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.PropertyType))) {
		$detMethodCommand += " -PropertyType $($DetectionMethod.PropertyType)"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.ExpectedValue))) {
		If ($DetectionMethod.ExpectedValue -like "*`$Version*") {
			Add-LogContent "[Detection] Replacing `$Version in $($DetectionMethod.ExpectedValue)"
			$DetectionMethod.ExpectedValue = ($DetectionMethod.ExpectedValue).Replace('$Version', $AppVersion)
		}
		If ($DetectionMethod.ExpectedValue -like "*`$FullVersion*") {
			Add-LogContent "[Detection] Replacing `$FullVersion in $($DetectionMethod.ExpectedValue)"
			$DetectionMethod.ExpectedValue = ($DetectionMethod.ExpectedValue).Replace('$FullVersion', $AppFullVersion)
		}
		$detMethodCommand += " -ExpectedValue `"$($DetectionMethod.ExpectedValue)`""
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.ExpressionOperator))) {
		$detMethodCommand += " -ExpressionOperator $($DetectionMethod.ExpressionOperator)"
	}
	If (([System.Convert]::ToBoolean($DetectionMethod.Value)) -and (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Value)))) {
		$detMethodCommand += " -Value"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.Hive))) {
		$detMethodCommand += " -Hive $($DetectionMethod.Hive)"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.KeyName))) {
		## Variable in KeyName
		If ($DetectionMethod.KeyName -like "*`$Version*") {
			Add-LogContent "[Detection] Replacing `$Version in $($DetectionMethod.KeyName)"
			$DetectionMethod.KeyName = ($DetectionMethod.KeyName).Replace('$Version', $AppVersion)
		}
		$detMethodCommand += " -KeyName `'$($DetectionMethod.KeyName)`'"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.ValueName))) {
		$detMethodCommand += " -ValueName `'$($DetectionMethod.ValueName)`'"
	}
	If (-not ([System.String]::IsNullOrEmpty($DetectionMethod.ProductCode))) {
		$detMethodCommand += " -ProductCode `'$($DetectionMethod.ProductCode)`'"
	}

	Push-Location
	Set-Location $SCCMSite
	## Run the Detection Method Command as Created by the Logic Above
	Try {
		$DepTypeDetectionMethod += Invoke-Expression $detMethodCommand
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		$FullyQualified = $_.Exeption.FullyQualifiedErrorID
		Add-LogContent "[Detection] ERROR: Creating Detection Method Clause Failed!" -Level "Error"
		Add-LogContent "[Detection] ERROR: $ErrorMessage" -Level "Error"
		Add-LogContent "[Detection] ERROR: $FullyQualified" -Level "Error"
	}
	Pop-Location

	## Return the Detection Method Variable
	Return $DepTypeDetectionMethod
}

Function Copy-CMDeploymentTypeRule {
    <#
	Function taken from https://janikvonrotz.ch/2017/10/20/configuration-manager-configure-requirement-rules-for-deployment-types-with-powershell/ and modified

     #>
	Param (
		[System.String]$SourceApplicationName,
		[System.String]$DestApplicationName,
		[System.String]$DestDeploymentTypeName,
		[System.String]$RuleName
	)
    Push-Location
    Set-Location $SCCMSite
	$DestDeploymentTypeIndex = 0

    # get the applications
    $SourceApplication = Get-CMApplication -Name $SourceApplicationName | ConvertTo-CMApplication
	$DestApplication = Get-CMApplication -Name $DestApplicationName | ConvertTo-CMApplication

	# Get DestDeploymentTypeIndex by finding the Title
	$DestApplication.DeploymentTypes | ForEach-Object {
		$i = 0
	} {
		If ($_.Title -eq "$DestDeploymentTypeName") {
			$DestDeploymentTypeIndex = $i

		}
		$i++
	}

	# get requirement rules from source application
    $Requirements = $SourceApplication.DeploymentTypes[0].Requirements | Where-Object {$_.Name -match $RuleName}

    # apply requirement rules
    $Requirements | ForEach-Object {

        $RuleExists = $DestApplication.DeploymentTypes[$DestDeploymentTypeIndex].Requirements | Where-Object {$_.Name -match $RuleName}
        if($RuleExists) {

            Add-LogContent "[Rules] WARN: The rule `"$($_.Name)`" already exists in target application deployment type"

        } else{

            Add-LogContent "[Rules] Apply rule `"$($_.Name)`" on target application deployment type"

            # create new rule ID
            $_.RuleID = "Rule_$( [guid]::NewGuid())"

            $DestApplication.DeploymentTypes[$DestDeploymentTypeIndex].Requirements.Add($_)
        }
    }

    # push changes
    $CMApplication = ConvertFrom-CMApplication -Application $DestApplication
    $CMApplication.Put()
    Pop-Location
}

Function Set-Supersedence {
	Param (
		$Recipe,
		$DeploymentTypeName
	)
	$Superseded = $true

	Push-Location
	Set-Location $SCCMSite

	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	ForEach ($Download In ($Recipe.ApplicationDef.Downloads.Download)) {
		If (-not ([System.String]::IsNullOrEmpty($Download.Version))) {
			$ApplicationVersion = $Download.Version
		}
	}

	Add-LogContent "[Supersedence] Supersedence for - AppName: $ApplicationName, SoftwareVersion: $ApplicationVersion, DeploymentTypeName: $DeploymentTypeName"
	
	## Getting AppPackage with last actual version to replace.
	$AllVersions = Get-CMApplication -Fast | Where-Object {$_.LocalizedDisplayName -Match [regex]::Escape($ApplicationName) -and $_.SoftwareVersion -ne $ApplicationVersion} | Select-Object SoftwareVersion
	$SupersededVersion = ($AllVersions | ForEach-Object { [System.Version]$_.SoftwareVersion } | Sort-Object -Descending)[0].ToString()

	$SupersededApplication = "$ApplicationName $SupersededVersion"
	
	$SupersededDeptType	= Get-CMDeploymentType -ApplicationName $SupersededApplication | Where-Object {$_.LocalizedDisplayName -Match [regex]::Escape($DeploymentTypeName) -and $_.IsSuperseded -eq $False}
	If ($SupersededDeptType){
		Add-LogContent "[Supersedence] Found Application to be superseded: $SupersededApplication created on $($SupersededDeptType.DateCreated)"
	} else {
		$Superseded = $False
		Add-LogContent "[Supersedence] No application to be superseded found. Skipping."
		Pop-Location
		return $Superseded
	}

	#This is our newly created application.
	$SupersedingAppName = "$ApplicationName $ApplicationVersion"
	$SupersederDeptType = Get-CMDeploymentType -ApplicationName $SupersedingAppName | Where-Object {$_.LocalizedDisplayName -Match [regex]::Escape($DeploymentTypeName)}
	if ($SupersederDeptType){
		Add-LogContent "[Supersedence] Superseding: $ApplicationName $ApplicationVersion $DeploymentTypeName $($SupersedingDeptType.DateCreated)"
	} else {
		$Superseded = $False
		Add-LogContent "[Supersedence] Whops, superseding application not found, something went wrong." -Level "Error"
		Pop-Location
		return $Superseded
	}

	try {
		Add-CMDeploymentTypeSupersedence -SupersededDeploymentType $SupersededDeptType -SupersedingDeploymentType $SupersederDeptType | Out-Null
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		Add-LogContent "[Supersedence] ERROR: Supersedence Failed!" -Level "Error"
		Add-LogContent "[Supersedence] ERROR: $ErrorMessage" -Level "Error"
		Pop-Location
		return $Superseded
	}

	Pop-Location
	return $Superseded

}

Function Update-TaskSequenceInstallApplication {
	Param (
		$Softwarename,
		$Softwareversion,
		$SoftwareTaskSequenceID
	)

	Push-Location
	Set-Location $SCCMSite

	$TaskSequenceName = Get-CMTaskSequence -TaskSequencePackageId $SoftwareTaskSequenceID | select -expandproperty Name
	
	Add-LogContent "[Task Sequence] Updating Task Sequence `"$TaskSequenceName`" and step name `"$Softwarename`" with application `"$Softwarename $Softwareversion`""
	try {
        $TaskSequence = Get-CMTaskSequence -TaskSequencePackageId $SoftwareTaskSequenceID
        if (@($TaskSequence | select name).length -ne 1){
            throw "Task Sequence has not been found or there are more Task Sequences with a given name."
        }

        if ($TaskSequence | Get-CMTaskSequenceStep -StepName "$Softwarename") {
            Add-LogContent "[Task Sequence] Editting step name `"$softwarename`""
	        $TaskSequence | Set-CMTSStepInstallApplication -StepName $Softwarename -Application (Get-CMApplication -Name "$Softwarename $Softwareversion")
        } else {
            Add-LogContent "[Task Sequence] Creating step name `"$softwarename`""
            $TaskSequenceStep =  New-CMTSStepInstallApplication -Name $softwarename  -Application (Get-CMApplication -Name "$Softwarename $Softwareversion") -ContinueOnInstallError
            $TaskSequence | Add-CMTaskSequenceStep -Step $TaskSequenceStep
        }
    } catch {
	    $ErrorMessage = $_.Exception.Message
	    $FullyQualified = $_.Exeption.FullyQualifiedErrorID
	    Add-LogContent "ERROR: Updating Task Sequence failed!"
	    Add-LogContent "ERROR: $ErrorMessage"
	    Add-LogContent "ERROR: $FullyQualified"
	}

	Pop-Location
}

Function Add-DeploymentType {
	Param (
		$Recipe
	)

	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	$ApplicationPublisher = $Recipe.ApplicationDef.Application.Publisher
	$ApplicationDescription = $Recipe.ApplicationDef.Application.Description
	$ApplicationDocURL = $Recipe.ApplicationDef.Application.UserDocumentation

	## Set Return Value to True, It will toggle to False if something Fails
	$DepTypeReturn = $true

	## Loop through each Deployment Type and Add them to the Application as needed
	ForEach ($DeploymentType In $Recipe.ApplicationDef.DeploymentTypes.ChildNodes) {
		$DepTypeName = $DeploymentType.Name
		$DepTypeDeploymentTypeName = $DeploymentType.DeploymentTypeName
		Add-LogContent "[Deployment Type] New DeploymentType - $DepTypeDeploymentTypeName"

		$AssociatedDownload = $Recipe.ApplicationDef.Downloads.Download | where DeploymentType -eq $DepTypeName
		$ApplicationSWVersion = $AssociatedDownload.Version
		$Version = $AssociatedDownload.Version
		If (-not ([String]::IsNullOrEmpty($AssociatedDownload.FullVersion))) {
			$FullVersion = $AssociatedDownload.FullVersion
		}

		# General
		$DepTypeApplicationName = "$ApplicationName $ApplicationSWVersion"
		$DepTypeInstallationType = $DeploymentType.InstallationType
		$InstallBehaviorAppName = $DeploymentType.InstallationBehaviorName
		Add-LogContent "[Deployment Type] Deployment Type Set as: $DepTypeInstallationType"

		$stDepTypeComment = $DeploymentType.Comments
		$DepTypeLanguage = $DeploymentType.Language

		# Content Settings
		# Content Location
		If ([String]::IsNullOrEmpty($AssociatedDownload.AppRepoFolder)) {
			$DepTypeContentLocation = "$Global:ContentLocationRoot\$ApplicationName\Packages\$Version"
		}
		Else {
			$DepTypeContentLocation = "$Global:ContentLocationRoot\$ApplicationName\Packages\$Version\$($AssociatedDownload.AppRepoFolder)"
		}
		$swDepTypeCacheContent = [System.Convert]::ToBoolean($DeploymentType.CacheContent)
		$swDepTypeEnableBranchCache = [System.Convert]::ToBoolean($DeploymentType.BranchCache)
		$swDepTypeContentFallback = [System.Convert]::ToBoolean($DeploymentType.ContentFallback)
		$stDepTypeSlowNetworkDeploymentMode = $DeploymentType.OnSlowNetwork

		# Programs
		$DepTypeInstallationProgram = $DeploymentType.InstallProgram
		$DepTypeUninstallationProgram = $DeploymentType.UninstallCmd
		$swDepTypeForce32Bit = [System.Convert]::ToBoolean($DeploymentType.Force32bit)

		# User Experience
		$stDepTypeInstallationBehaviorType = $DeploymentType.InstallationBehaviorType
		$stDepTypeLogonRequirementType = $DeploymentType.LogonReqType
		$stDepTypeUserInteractionMode = $DeploymentType.UserInteractionMode
		$swDepTypeRequireUserInteraction = [System.Convert]::ToBoolean($DeploymentType.ReqUserInteraction)
		$stDepTypeEstimatedRuntimeMins = $DeploymentType.EstRuntimeMins
		$stDepTypeMaximumRuntimeMins = $DeploymentType.MaxRuntimeMins
		$stDepTypeRebootBehavior = $DeploymentType.RebootBehavior

		$DepTypeDetectionMethodType = $DeploymentType.DetectionMethodType
		Add-LogContent "[Deployment Type] Detection Method Type Set as $DepTypeDetectionMethodType"

		$DepTypeAddDetectionMethods = $false

		If (($DepTypeDetectionMethodType -eq "Custom") -and (-not ([System.String]::IsNullOrEmpty($DeploymentType.CustomDetectionMethods.ChildNodes)))) {
			$DepTypeDetectionMethods = @()
			$DepTypeAddDetectionMethods = $true
			Add-LogContent "[Deployment Type] Adding Detection Method Clauses"

			ForEach ($DetectionMethod In $DeploymentType.CustomDetectionMethods.ChildNodes) {
				Add-LogContent "[Deployment Type] New Detection Method Clause $Version $FullVersion"
				$DepTypeDetectionMethods += Add-DetectionMethodClause -DetectionMethod $DetectionMethod -AppVersion $Version -AppFullVersion $FullVersion
			}
		}

		Switch ($DepTypeInstallationType) {
			Script {
				#Write-Host "Script Deployment"
				$DepTypeCommand = "Add-CMScriptDeploymentType -ApplicationName `"$DepTypeApplicationName`" -ContentLocation `"$DepTypeContentLocation`" -DeploymentTypeName `"$DepTypeDeploymentTypeName`""
				$CmdSwitches = ""

				## Build the Rest of the command based on values in the xml
				## Switch type Arguments
				ForEach ($DepTypeVar In $(Get-Variable | Where-Object {
							$_.Name -like "swDepType*"
						})) {
					If (([System.Convert]::ToBoolean($deptypevar.Value)) -and (-not ([System.String]::IsNullOrEmpty($DepTypeVar.Value)))) {
						$CmdSwitch = "-$($($DepTypeVar.Name).Replace("swDepType", ''))"
						$CmdSwitches += " $CmdSwitch"
					}
				}

				## String Type Arguments
				ForEach ($DepTypeVar In $(Get-Variable | Where-Object {
							$_.Name -like "stDepType*"
						})) {
					If (-not ([System.String]::IsNullOrEmpty($DepTypeVar.Value))) {
						$CmdSwitch = "-$($($DepTypeVar.Name).Replace("stDepType", '')) `"$($DepTypeVar.Value)`""
						$CmdSwitches += " $CmdSwitch"
					}
				}

				## Script Install Type Specific Arguments
				$DepTypeInstallationProgram = ($DepTypeInstallationProgram).Replace("REPLACEMEWITHTHEAPPVERSION", $($AssociatedDownload.Version)).replace("REPLACEMEWITHTHEAPPFULLVERSION", $($AssociatedDownload.FullVersion))
				$CmdSwitches += " -InstallCommand `'$DepTypeInstallationProgram`'"
				If (-not ([string]::IsNullOrEmpty($DepTypeUninstallationProgram))) {
					$DepTypeUninstallationProgram = ($DepTypeUninstallationProgram).Replace("REPLACEMEWITHTHEAPPVERSION", $($AssociatedDownload.Version)).replace("REPLACEMEWITHTHEAPPFULLVERSION", $($AssociatedDownload.FullVersion))
					$CmdSwitches += " -UninstallationProgram `'$DepTypeUninstallationProgram`'"
				}

				If ($DepTypeDetectionMethodType -eq "CustomScript") {
					$DepTypeScriptLanguage = $DeploymentType.ScriptLanguage
					If (-not ([string]::IsNullOrEmpty($DepTypeScriptLanguage))) {
						$CMDSwitch = "-ScriptLanguage `"$DepTypeScriptLanguage`""
						$CmdSwitches += " $CmdSwitch"
					}

					$DepTypeScriptText = ($DeploymentType.DetectionMethod).Replace("REPLACEMEWITHTHEAPPVERSION", $($AssociatedDownload.Version)).replace("REPLACEMEWITHTHEAPPFULLVERSION", $($AssociatedDownload.FullVersion))
					If (-not ([string]::IsNullOrEmpty($DepTypeScriptText))) {
						$CMDSwitch = "-ScriptText `'$DepTypeScriptText`'"
						$CmdSwitches += " $CmdSwitch"
					}
				}

				$DepTypeForce32BitDetection = $DeploymentType.ScriptDetection32Bit
				If (([System.Convert]::ToBoolean($DepTypeForce32BitDetection)) -and (-not ([System.String]::IsNullOrEmpty($DepTypeForce32BitDetection)))) {
					$CmdSwitches += " -ForceScriptDetection32Bit"
				}

				## Run the Add-CMApplicationDeployment Command
				$DeploymentTypeCommand = "$DepTypeCommand$CmdSwitches"
				If ($DepTypeAddDetectionMethods) {
					$DeploymentTypeCommand += " -ScriptType Powershell -ScriptText `"write-output 0`""
				}
				Add-LogContent "Creating DeploymentType"
				Add-LogContent "Command: $DeploymentTypeCommand"
				Push-Location
				Set-Location $SCCMSite
				Try {
					Invoke-Expression $DeploymentTypeCommand | Out-Null
				}
				Catch {
					$ErrorMessage = $_.Exception.Message
					$FullyQualified = $_.Exeption.FullyQualifiedErrorID
					Add-LogContent "ERROR: Creating Deployment Type Failed!" -Level "Error"
					Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
					Add-LogContent "ERROR: $FullyQualified" -Level "Error"
					$DepTypeReturn = $false
				}

				## Add Detection Methods if required for this Deployment Type
				If ($DepTypeAddDetectionMethods) {
					Add-LogContent "Adding Detection Methods"
					Add-LogContent "Set-CMScriptDeploymentType -ApplicationName $DepTypeApplicationName -DeploymentTypeName $DepTypeDeploymentTypeName -AddDetectionClause $($DepTypeDetectionMethods[0].DataType.Name)"
					Try {
						Set-CMScriptDeploymentType -ApplicationName "$DepTypeApplicationName" -DeploymentTypeName "$DepTypeDeploymentTypeName" -AddDetectionClause $DepTypeDetectionMethods
					}
					Catch {
						$ErrorMessage = $_.Exception.Message
						$FullyQualified = $_.Exeption.FullyQualifiedErrorID
						Add-LogContent "ERROR: Adding Detection Method Failed!" -Level "Error"
						Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
						Add-LogContent "ERROR: $FullyQualified" -Level "Error"
						$DepTypeReturn = $false
					}
				}
				Pop-Location

			}
			MSI {
				$DepTypeInstallationMSI = $DeploymentType.InstallationMSI
				$DepTypeCommand = "Add-CMMsiDeploymentType -ApplicationName `"$DepTypeApplicationName`" -ContentLocation `"$DepTypeContentLocation\$DepTypeInstallationMSI`" -DeploymentTypeName `"$DepTypeDeploymentTypeName`""
				$CmdSwitches = ""
				## Build the Rest of the command based on values in the xml
				ForEach ($DepTypeVar In $(Get-Variable | Where-Object {
							$_.Name -like "swDepType*"
						})) {
					If (([System.Convert]::ToBoolean($deptypevar.Value)) -and (-not ([System.String]::IsNullOrEmpty($DepTypeVar.Value)))) {
						$CmdSwitch = "-$($($DepTypeVar.Name).Replace("swDepType", ''))"
						$CmdSwitches += " $CmdSwitch"
					}
				}

				ForEach ($DepTypeVar In $(Get-Variable | Where-Object {
							$_.Name -like "stDepType*"
						})) {
					If (-not ([System.String]::IsNullOrEmpty($DepTypeVar.Value))) {
						$CmdSwitch = "-$($($DepTypeVar.Name).Replace("stDepType", '')) `"$($DepTypeVar.Value)`""
						$CmdSwitches += " $CmdSwitch"
					}
				}

				## Special Arguments based on Detection Method
				Switch ($DepTypeDetectionMethodType) {
					MSI {
						If (-not ([string]::IsNullOrEmpty($DepTypeInstallationProgram))) {
							$CmdSwitches += " -InstallCommand `"$DepTypeInstallationProgram`""
						}

						$DepTypeProductCode = $DeploymentType.ProductCode
						If (-not ([string]::IsNullOrEmpty($DepTypeProductCode))) {
							$CMDSwitch = "-ProductCode `"$DepTypeProductCode`""
							$CmdSwitches += " $CmdSwitch"
						}
					}
					CustomScript {
						$CmdSwitches += " -InstallCommand `"$DepTypeInstallationProgram`""

						$DepTypeScriptLanguage = $DeploymentType.ScriptLanguage
						If (-not ([string]::IsNullOrEmpty($DepTypeScriptLanguage))) {
							$CMDSwitch = "-ScriptLanguage `"$DepTypeScriptLanguage`""
							$CmdSwitches += " $CmdSwitch"
						}

						$DepTypeForce32BitDetection = $DeploymentType.ScriptDetection32Bit
						If (([System.Convert]::ToBoolean($DepTypeForce32BitDetection)) -and (-not ([System.String]::IsNullOrEmpty($DepTypeForce32BitDetection)))) {
							$CmdSwitches += " -ForceScriptDetection32Bit"
						}

						$DepTypeScriptText = ($DeploymentType.DetectionMethod).Replace("REPLACEMEWITHTHEAPPVERSION", $($AssociatedDownload.Version))
						If (-not ([string]::IsNullOrEmpty($DepTypeScriptText))) {
							$CMDSwitch = "-ScriptText `'$DepTypeScriptText`'"
							$CmdSwitches += " $CmdSwitch"
						}
					}
				}

				## Run the Add-CMApplicationDeployment Command
				Push-Location
				Set-Location $SCCMSite
				$DeploymentTypeCommand = "$DepTypeCommand$CmdSwitches -Force"
				Add-LogContent "[Deployment Type] Creating DeploymentType"
				Add-LogContent "Command: $DeploymentTypeCommand"
				Try {
					Invoke-Expression $DeploymentTypeCommand | Out-Null
				}
				Catch {
					$ErrorMessage = $_.Exception.Message
					$FullyQualified = $_.Exeption.FullyQualifiedErrorID
					Add-LogContent "[Deployment Type] ERROR: Adding MSI Deployment Type Failed!" -Level "Error"
					Add-LogContent "[Deployment Type] ERROR: $ErrorMessage" -Level "Error"
					Add-LogContent "[Deployment Type] ERROR: $FullyQualified" -Level "Error"
					$DepTypeReturn = $false
				}
				If ($DepTypeAddDetectionMethods) {
					Add-LogContent "[Deployment Type] Adding Detection Methods"
					Add-LogContent "[Deployment Type] Set-CMMsiDeploymentType -ApplicationName $DepTypeApplicationName -DeploymentTypeName $DepTypeDeploymentTypeName -AddDetectionClause $($DepTypeDetectionMethods[0].DataType.Name)"
					Try {
						Set-CMMsiDeploymentType -ApplicationName "$DepTypeApplicationName" -DeploymentTypeName "$DepTypeDeploymentTypeName" -AddDetectionClause $DepTypeDetectionMethods
					}
					Catch {
						$ErrorMessage = $_.Exception.Message
						$FullyQualified = $_.Exeption.FullyQualifiedErrorID
						Add-LogContent "[Deployment Type] ERROR: Adding Detection Method Failed!" -Level "Error"
						Add-LogContent "[Deployment Type] ERROR: $ErrorMessage" -Level "Error"
						Add-LogContent "[Deployment Type] ERROR: $FullyQualified" -Level "Error"
						$DepTypeReturn = $false
					}
				}
				Pop-Location
			}
			Default {
				$DepTypeReturn = $false
			}
		}

		## Add Requirements for Deployment Type if they exist
		If (-not [System.String]::IsNullOrEmpty($DeploymentType.Requirements)) {
			Add-LogContent "[Deployment Type] Adding Requirements to $DepTypeDeploymentTypeName"
			$DepTypeRules = $DeploymentType.Requirements.RuleName
			ForEach ($DepTypeRule In $DepTypeRules) {
				Copy-CMDeploymentTypeRule -SourceApplicationName $Global:RequirementsTemplateAppName -DestApplicationName $DepTypeApplicationName -DestDeploymentTypeName $DepTypeDeploymentTypeName -RuleName $DepTypeRule
			}
		}

		## Set supersedence.
		Add-LogContent "[Deployment Type] Creating Supersedence!"
		Set-Supersedence -Recipe $Recipe -DeploymentTypeName $DepTypeDeploymentTypeName


		## Set Install Behavior
		If (!([string]::IsNullOrEmpty($InstallBehaviorAppName))) {
			Add-LogContent "[Install Behavior] Creating Install Behavior."
			Set-InstallBehavior -AppName "$ApplicationName $ApplicationSWVersion" -DeploymentTypeName $DepTypeDeploymentTypeName -InstallBehaviorAppName $InstallBehaviorAppName
		}

	}

	## Add Dependencies for Deployment Type if they exist
	if (-not [System.String]::IsNullOrEmpty($DeploymentType.Dependencies)){
		Add-LogContent "[Dependencies] Adding Dependencies to $DepTypeDeploymentTypeName"
		$DepTypeDependencyGroups = $DeploymentType.Dependencies.DependencyGroup
		foreach ($DepTypeDependencyGroup in $DepTypeDependencyGroups){
			Add-LogContent "Creating Dependency Group $($DepTypeDependencyGroup.GroupName) on $DepTypeDeploymentTypeName"
			Push-Location
			Set-Location $SCCMSite
			$DependencyGroup = Get-CMDeploymentType -ApplicationName $DepTypeApplicationName -DeploymentTypeName $DepTypeDeploymentTypeName | New-CMDeploymentTypeDependencyGroup -GroupName $DepTypeDependencyGroup.GroupName
			$DepTypeDependencyGroupApps = $DepTypeDependencyGroup.DependencyGroupApp
			foreach ($DepTypeDependencyGroupApp in $DepTypeDependencyGroupApps){
				$DependencyGroupAppAutoInstall = [System.Convert]::ToBoolean($DepTypeDependencyGroupApp.DependencyAutoInstall)
				$DependencyAppName = ((Get-CMApplication $DepTypeDependencyGroupApp.AppName | Sort-Object -Property Version -Descending | Select-Object -First 1).LocalizedDisplayName)
				if (-not [System.String]::IsNullOrEmpty($DepTypeDependencyGroupApp.DependencyDepType)){
					Add-LogContent "Selecting Deployment Type for App Dependency: $($DepTypeDependencyGroupApp.DependencyDepType)"
					$DependencyAppObject = Get-CMDeploymentType -ApplicationName $DependencyAppName -DeploymentTypeName "$($DepTypeDependencyGroupApp.DependencyDepType)"
				} else {
					$DependencyAppObject = Get-CMDeploymentType -ApplicationName $DependencyAppName
				}
				$DependencyGroup | Add-CMDeploymentTypeDependency -DeploymentTypeDependency $DependencyAppObject -IsAutoInstall $DependencyGroupAppAutoInstall
			}
			Pop-Location
		}
	}


	Return $DepTypeReturn
}

Function Distribute-Application {
	Param (
		$Recipe
	)
	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	ForEach ($Download In ($Recipe.ApplicationDef.Downloads.Download)) {
		If (-not ([System.String]::IsNullOrEmpty($Download.Version))) {
			$ApplicationSWVersion = $Download.Version
		}
	}
	$Success = $true
	## Distributes the Content for the Created Application based on the Information in the Recipe XML under the Distribution Node
	Push-Location
	Set-Location $SCCMSite
	$DistContent = [System.Convert]::ToBoolean($Recipe.ApplicationDef.Distribution.DistributeContent)
	If ($DistContent) {

		If (-not([string]::IsNullOrEmpty($Recipe.ApplicationDef.Distribution.DistributeToGroup))) {
			$DistributionGroup = $Recipe.ApplicationDef.Distribution.DistributeToGroup
			Add-LogContent "[Distribution] Distributing Content for $ApplicationName $ApplicationSWVersion to $($Recipe.ApplicationDef.Distribution.DistributeToGroup)"
			Try {
				Start-CMContentDistribution -ApplicationName "$ApplicationName $ApplicationSWVersion" -DistributionPointGroupName $DistributionGroup -ErrorAction Stop
			}
			Catch {
				$ErrorMessage = $_.Exception.Message
				Add-LogContent "[Distribution] ERROR: Content Distribution Failed!" -Level "Error"
				Add-LogContent "[Distribution] ERROR: $ErrorMessage" -Level "Error"
				$Success = $false
			}
		}
		If (-not ([string]::IsNullOrEmpty($Recipe.ApplicationDef.Distribution.DistributeToDPs))) {
			Add-LogContent "[Distribution] Distributing Content to $($Recipe.ApplicationDef.Distribution.DistributeToDPs)"
			$DistributionDPs = ($Recipe.ApplicationDef.Distribution.DistributeToDPs).Split(",")
			ForEach ($DistributionPoint In $DistributionDPs) {
				Try {
					Start-CMContentDistribution -ApplicationName "$ApplicationName $ApplicationSWVersion" -DistributionPointName $DistributionPoint -ErrorAction Stop
				}
				Catch {
					$ErrorMessage = $_.Exception.Message
					Add-LogContent "[Distribution] ERROR: Content Distribution Failed!" -Level "Error"
					Add-LogContent "[Distribution] ERROR: $ErrorMessage" -Level "Error"
					$Success = $false
				}
			}
		}
		##Use prefered DistributionPointName defined in $Global:PreferredDistributionLoc (pref)
		If ((([string]::IsNullOrEmpty($Recipe.ApplicationDef.Distribution.DistributeToDPs)) -and ([string]::IsNullOrEmpty($Recipe.ApplicationDef.Distribution.DistributeToGroup))) -and (-not ([String]::IsNullOrEmpty($Global:PreferredDistributionLoc)))) {
			$DistributionPointName = $Global:PreferredDistributionLoc
			Add-LogContent "[Distribution] Distribution was set to True but No Distribution Points or Groups were Selected, Using Preferred Distribution Group: $Global:PreferredDistributionLoc"
			Try {
				Start-CMContentDistribution -ApplicationName "$ApplicationName $ApplicationSWVersion" -DistributionPointName $DistributionPointName -ErrorAction Stop
			}
			Catch {
				$ErrorMessage = $_.Exception.Message
				Add-LogContent "[Distribution] ERROR: Content Distribution Failed!" -Level "Error"
				Add-LogContent "[Distribution] ERROR: $ErrorMessage" -Level "Error"
				$Success = $false
			}
		}
	}
	Pop-Location
	Return $Success
}
Function Deploy-Application-Handler {
	Param (
		$Recipe
	)

	if (-not ([string]::IsNullOrEmpty($Recipe.ApplicationDef.Deployments.TestFirst)) -and [System.Convert]::ToBoolean($Recipe.ApplicationDef.Deployments.TestFirst)){
		return Deploy-Application -Recipe $Recipe -Type "Test"
	} else {
		return Deploy-Application -Recipe $Recipe -Type "Production"
	}

}
Function Deploy-Application {
	Param (
		$Recipe,
		$Type,
		$Unattend = $False
	)

	$Deployed = $true
	$ApplicationName = $Recipe.ApplicationDef.Application.Name
	ForEach ($Download In ($Recipe.ApplicationDef.Downloads.Download)) {
		If (-not ([System.String]::IsNullOrEmpty($Download.Version))) {
			$ApplicationSWVersion = $Download.Version
		}
	}

	## Deploys the Created application based on the Information in the Recipe XML under the Deployment Node
	Push-Location
	Set-Location $SCCMSite

	If ($Type -eq "Test"){
		$DeploymentsList = $Recipe.ApplicationDef.Deployments.Deployment | Where-Object { $_.type -eq "Test"}
	} else {
		$DeploymentsList = $Recipe.ApplicationDef.Deployments.Deployment | Where-Object { $_.type -ne "Test"}
	}

	# Update Software in Task Sequence
	ForEach ($TaskSequenceID in $Recipe.ApplicationDef.Tasksquences.TasksquenceID) {
		Update-TaskSequenceInstallApplication -Softwarename $ApplicationName -Softwareversion $ApplicationSWVersion -SoftwareTaskSequenceID $TaskSequenceID
	}

	ForEach ($Deployment in $DeploymentsList){

		#$DeployAction = $Deployment.DeployAction
		$DeployPurpose = $Deployment.DeployPurpose
		$UserNotification = $Deployment.UserNotification

		If ([System.Convert]::ToBoolean($Deployment.DeploySoftware)) {
			If (-not ([string]::IsNullOrEmpty($Deployment.DeploymentCollection))) {
				Try {
					Add-LogContent "[Deployment] Deploying $ApplicationName $ApplicationSWVersion to $($Deployment.DeploymentCollection)"
					# For the moment this must be disabled - we shall see
					# Get-CMDeployment -CollectionName $Deployment.DeploymentCollection -FeatureType Application | Select-Object -Skip 2 | Remove-CMDeployment -Force
					If (($Unattend) -and ($Type -ne "Test")){
						Add-LogContent "[Unattend Deployment] Scheduled to 7 days as Available!"
						New-CMApplicationDeployment -CollectionName $Deployment.DeploymentCollection -Name "$ApplicationName $ApplicationSWVersion" -AvailableDateTime (get-date).AddDays(7) -DeployAction Install -DeployPurpose $DeployPurpose -UserNotification $UserNotification -UpdateSupersedence $True -ErrorAction Stop | Out-Null
					} else {
						New-CMApplicationDeployment -CollectionName $Deployment.DeploymentCollection -Name "$ApplicationName $ApplicationSWVersion" -DeployAction Install -DeployPurpose $DeployPurpose -UserNotification $UserNotification -UpdateSupersedence $True -ErrorAction Stop | Out-Null
					}
						If ($Type -eq "Test"){
						Invoke-CMClientNotification -DeviceCollectionName $Deployment.DeploymentCollection -ActionType ClientNotificationRequestMachinePolicyNow
					}
				}
				Catch {
					$ErrorMessage = $_.Exception.Message
					Add-LogContent "[Deployment] ERROR: Deployment Failed!" -Level "Error"
					Add-LogContent "[Deployment] ERROR: $ErrorMessage" -Level "Error"
					$Deployed = $false
				}
			}
		}
	}
	Pop-Location

	return $Deployed, $Type

}
function Set-InstallBehavior {
	Param (
		$AppName,
		$DeploymentTypeName,
		$InstallBehaviorAppName
	)

	Push-Location
	Set-Location $Global:SCCMSite

	try {
		$Application = Get-CMApplication -Name "$AppName"
	} catch {
		$ErrorMessage = $_.Exception.Message
		Add-LogContent "ERROR: Adding Install behavior app name failed! At getting cmaplication." -Level "Error"
		Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
        Write-Output $ErrorMessage
	}

	$SDMPackageXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($Application.SDMPackageXML, $True)
	[Microsoft.ConfigurationManagement.ApplicationManagement.ProcessInformation]$obj = @{
		"Name"=$InstallBehaviorAppName;
		"IsReadOnly"=$False; 
		"IsChanged"=$False
	}

	($SDMPackageXML.DeploymentTypes | Where {$_.Title -eq $DeploymentTypeName}).Installer.InstallProcessDetection.ProcessList.Add($obj)
	$Application.SDMPackageXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::Serialize($SDMPackageXML, $false)

	try {
		$Application.put()
	} catch {
		$ErrorMessage = $_.Exception.Message
        Write-Output $ErrorMessage
		Add-LogContent "ERROR: Adding Install behavior app name failed! At put() method." -Level "Error"
		Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
	}

	Pop-Location

}
function Generate-EmailMessage {
	Param (
		$TestDeploy = $False
	)
	$Message = "V centralnej správe prebehla aktualizacia nasledujucich aplikacii. `n`n"

	if ($TestDeploy) {
		$Message += $Global:EmailBody + "`n"
		$Message += "_______________________________________________________`n"
		$Message += "Prosíme o kontrolu tychto aplikácií a v prípade akýchkoľvek problémov nás kontaktujte odpoveďou na tuto spravu.`n"
		$Message += "Zamerajte sa prosím hlavne na tieto body:`n"
		$Message += "   - Centrum softwaru uspesne nainstalovalo aplikaciu na danu verziu.`n"
		$Message += "   - Aplikacia je po aktualizacii na danej verzii`n"
		$Message += "   - Po aktualizaciach si pocitac nevyzaduje ziaden restart`n"
		$Message += "   - Aplikacia si zachovala svoju funkcnost.`n"
		$Message += "Kontrolu vykonávajte na počítačoch OBSLUHA01-PC az OBSLUHA06-PC`n`n"
	} else {
		$Message += Get-NextNotification + "`n"
		$Message += "V prípade akýchkoľvek problémov nás, prosim, kontaktujte odpoveďou na tuto spravu.`n`n"
	}
	$Message += "S pozdravom,`n~Aktualizator [winadm@ics.muni.cz]`n"
	$Message += "//Táto správa bola vygenerovaná automaticky."


	return $Message

}
Function Send-EmailMessage {
	Param (
		$EmailBody,
		$EmailTo,
		$EmailSubject = $Global:EmailSubject
	)

	Add-LogContent "Sending Email To: $EmailTo"
	Try {
		Send-MailMessage -To $EmailTo -Bcc $Global:EmailToAdmins -Subject $EmailSubject -From "Aktualizator <$Global:EmailFrom>" -Body $EmailBody -SmtpServer $Global:EmailServer -Encoding "UTF8" -ErrorAction Stop
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Add-LogContent "ERROR: Sending Email Failed!" -Level "Error"
		Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
	}
}

Function Send-TeamsMessage  {
	Param (
		$Team
	)

	$EmailBody = Get-NextNotification

	if ($Team -eq "demo"){
		#demo
		$uri = "https://outlook.office.com/webhook/91765e2f-4b98-4ef7-8b70-4be4efa3dc0d@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/fd30748fd5da4fc3b628066f0edcd6bf/7d2da52d-357e-408b-a9be-52bf1cab5332"
	} elseif ($Team -eq "prod") {
		#official
		# $uri = "https://outlook.office.com/webhook/22969e92-09c1-4f09-9a2b-70ad5574e91a@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/7b1aea5900c049ab9c16cb6813bfa95c/7d2da52d-357e-408b-a9be-52bf1cab5332"
		#$uri = "https://outlook.office.com/webhook/8bf58b91-611a-4ab2-8270-4392b24368f6@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/5646310159034b1681d88b3cb7acae3f/5de5536e-5cfa-40b7-92eb-9bbac8abbfa6"
		$uri = "https://ucnmuni.webhook.office.com/webhookb2/8bf58b91-611a-4ab2-8270-4392b24368f6@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/008e179969f94d9a923b6cee9f83391d/cb2d5fce-f2fc-4fd9-aa21-2f48ecbc2518"
	
	}

	$body = ConvertFrom-Json '{"@type": "MessageCard", "@context": "https://schema.org/extensions", "summary": "Aktualizacie softwaru", "themeColor": "0000dc", "title": "Aktualizacie softwaru", "sections": [ { "title": "V centralnej sprave boli aktualizovane nasledujuce aplikacie." }, { "text": "" }, { "text": "V pripade problemov prosim vyuzite servicedesk it@muni.cz." } ] }'
	$body.sections[1].text = Get-NextNotification

	$body = ConvertTo-Json $body
	Try {
		Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Add-LogContent "ERROR: Sending message to Teams Failed!" -Level "Error"
		Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
	}

}

function Read-UserInput {
    param(
        $Message,
        $MessageYes = "",
        $MessageNo = ""
    )
    $uinput = Read-Host "$Message [Yes] $MessageYes/ [No] $MessageNo"
    switch -regex ($uinput.ToLower()) {
        "^y(es?)?$" {
            return $True
         }
        Default {
        	return $False
        }
    }
}

function Store-NextNotification {
	param (
		$Email
	)
 	$Email > $Global:NextMailFilePath
}

function Get-NextNotification {
	if ($Unattend) {
		return (Get-Content -Path $Global:NextMailFilePath | Out-String)
	}
	return $Global:EmailBody
}
################################### MAIN ########################################
## Startup

Add-LogContent "[Startup] Starting up app packager" -Load -Level "Info" -ForceError

## Allow all Cookies to download (Prevents Script from Freezing)
try {
	Add-LogContent "[Startup] Allowing All Cookies to Download (This prevents the script from freezing on a download)"
	reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3" /t REG_DWORD /v 1A10 /f /d 0
} catch {
	$ErrorMessage = $_.Exception.Message
	Add-LogContent "ERROR: Registry add failed!" -Level "Error"
	Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
}

## Import ConfigurationManager module
if (-not (Get-Module ConfigurationManager)) {
	try {
		Add-LogContent "Importing ConfigurationManager Module"
		Import-Module (Join-Path $(Split-Path $env:SMS_ADMIN_UI_PATH) ConfigurationManager.psd1) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		Add-LogContent "ERROR: Importing ConfigurationManager Module Failed!" -Level "Error"
		Add-LogContent "ERROR: $ErrorMessage" -Level "Error"
	}
}

## Create the Temp Folder if needed
Add-LogContent "Creating SCCMPackager Folder"
if (-not (Test-Path $Global:TempDir)) {
	New-Item -ItemType Container -Path "$Global:TempDir" -Force -ErrorAction SilentlyContinue
}

## Get the Recipes
if (!($Unattend)){
	$RecipeList = Get-ChildItem $Global:ScriptRoot\Recipes\ | Select-Object -Property Name -ExpandProperty Name | Out-GridView -OutputMode Multiple -Title "Choose which recipes should App Packager use."
} else {
	$RecipeList = Get-ChildItem $Global:ScriptRoot\Recipes\ | Select-Object -Property Name -ExpandProperty Name | Where-Object -Property Name -NE "Template.xml"
}

Add-LogContent -Content "All Recipes: $RecipeList"

## List of Applications that were actually created (Only ).
## @{"Software" = "Version",...}
$AppsCreated = @{}

## List of apps that are marked as TestFirst.
$TestAppsRecipes = New-Object System.Collections.ArrayList
$TestApps = New-Object System.Collections.ArrayList

## Begin Looping through all the Recipes
ForEach ($Recipe In $RecipeList) {
	## Reset All Variables
	$Download = $False
	$ApplicationCreation = $False
	$DeploymentTypeCreation = $False
	$ApplicationDistribution = $False
	$ApplicationDeployment = $False
	$AppDeployed = $False

	## Import Recipe
	Add-LogContent "Importing Content for $Recipe" "Info" -ForceError
	[xml]$ApplicationRecipe = Get-Content "$PSScriptRoot\Recipes\$Recipe"

	## Perform Packaging Tasks
	$Download = Download-Application -Recipe $ApplicationRecipe
	Add-LogContent "Continue to Download: $Download"
	If ($Download) {
		$ApplicationCreation = Create-Application -Recipe $ApplicationRecipe
		Add-LogContent "Continue to ApplicationCreation: $ApplicationCreation"
	}
	If ($ApplicationCreation[0]) {
		$DeploymentTypeCreation = Add-DeploymentType -Recipe $ApplicationRecipe
		Add-LogContent "Continue to DeploymentTypeCreation: $DeploymentTypeCreation"
	}
	If ($DeploymentTypeCreation) {
		$ApplicationDistribution = Distribute-Application -Recipe $ApplicationRecipe
		Add-LogContent "Continue to ApplicationDistribution: $ApplicationDistribution"
	}
	If ($ApplicationDistribution) {
		$AppDeployed = Deploy-Application-Handler -Recipe $ApplicationRecipe
		Add-LogContent "Continue to ApplicationDeployment: $ApplicationDeployment"
	}
	If ($AppDeployed){
		$AppsCreated[$ApplicationCreation[1]] = $ApplicationCreation[2]
		If ($AppDeployed[1] -eq "Test"){
			Add-LogContent "Application $($ApplicationCreation[1]) is deployed to TestFirst collection. Waiting to deploy to production."
			$TestAppsRecipes.Add($ApplicationRecipe) | Out-Null
			$TestApps.Add($ApplicationRecipe.ApplicationDef.Application.Name) | Out-Null
		}
	}
}

## Run deployment on TestAppsRecipes after confirmation.
if ($TestAppsRecipes -ne $null){
	if (!($Unattend)){
		Write-Host "Following applications were deployed to Test collection, please chcek if applications are being installed correctly." -ForegroundColor Green
		Write-Host "note: Application that isn't being installed correctly should be fixed and deployed to production in the next step." -ForegroundColor Yellow
		Write-host ($TestApps) -Separator ",`n"

		if (Read-UserInput "Are all applications successfully installed?"){
			Add-LogContent "Moving application to 'Production'"
			foreach ($App in $TestAppsRecipes) {
				Deploy-Application -Recipe $App -Type "Production" | Out-Null
			}
			Write-Host -ForegroundColor green "All applications were successfully deployed."
		} else {
			Write-Host "K. Bye."
			return 0 | Out-Null
		}

	} else {
		Add-LogContent "[Unattend] Moving application to 'Production'"
		foreach ($App in $TestAppsRecipes) {
			Deploy-Application -Recipe $App -Type "Production" -Unattend $True | Out-Null
		}

	}
}
Add-LogContent "Apps that were deployed: $($AppsCreated.Keys -join ', ')" -Level "Info" -ForceError

foreach ($App in $AppsCreated.Keys){
	$Global:EmailBody += "  - $App na verziu $($AppsCreated[$App])`n"
}

If ($SendEmail -and $SendEmailPreference -and $Mailer) {
	$Message = Get-NextNotification
	if (!([string]::IsNullOrEmpty($Message))) {
		Send-TeamsMessage -Team $Team
		Send-EmailMessage -EmailBody (Generate-EmailMessage) -EmailTo $Global:EmailToPROD
	}
	if ($AppsCreated.Count -gt 0) {
		Send-EmailMessage -EmailBody (Generate-EmailMessage -TestDeploy $True) -EmailTo $Global:EmailToTEST -EmailSubject $($Global:EmailSubject+" - TESTOVANIE")
		Store-NextNotification -Email $Global:EmailBody
	}
}

Add-LogContent "Cleaning Up Temp Directory $TempDir" -Level "Info" -ForceError
Remove-Item -Path $TempDir -Recurse -Force
Add-LogContent "--- End Of SCCM AutoPackager ---" -Level "Info" -ForceError

if ((Get-ChildItem -Path $Global:ErrorLogFile).Length -ne 0) {
	Send-EmailMessage -EmailTo $Global:EmailToAdmins -EmailSubject "Aktualizator Error log $(Get-Date -UFormat '%d.%m.%Y')" -EmailBody (Get-Content -Path $Global:ErrorLogFile -Raw)
}