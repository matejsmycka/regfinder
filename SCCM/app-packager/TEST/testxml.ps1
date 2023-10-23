[xml]$Recipe = Get-Content "D:\Users\469240\Desktop\git_projects\app-packager\Recipes\FirefoxQuantumESR.xml"

ForEach ($Deployment in $Recipe.ApplicationDef.Deployments.Deployment | Where { $_.type -eq "Test"}){
    Write-Output $Deployment.DeploymentCollection
} 
$Apps = @{
    "One App"="67.4";
    "Second App"="5.55";
    "Chrome App"="55.05";
    "Android App"="67.5";

}
$Global:EmailSubject = "Aktualizacie Softwaru"
$Global:EmailBody = "Boli aktualizovane nasledujuce aplikacie:`n`n"
<#$Global:EmailBody += "  - TEST-Google Chrome na verziu 67.0.3396.99`n"
$Global:EmailBody += "  - Notepad++ na verziu 7.5.7.0`n"
$Global:EmailBody += "  - Opera na verziu 55.55.55`n"
##>

foreach ($App in $Apps.Keys){
    $Global:EmailBody += "  - $App na verziu $($Apps[$App])`n"
}
Function Send-TeamsMessage  {

	$uri = "https://outlook.office.com/webhook/91765e2f-4b98-4ef7-8b70-4be4efa3dc0d@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/fd30748fd5da4fc3b628066f0edcd6bf/7d2da52d-357e-408b-a9be-52bf1cab5332"

	$body = ConvertTo-Json -Depth 4 @{
		title = $Global:EmailSubject
		text = $Global:EmailBody
		sections = @(
			@{
				title = 'V pripade problemov prosim vyuzite servicedesk it@muni.cz.'
			}
		)
    }
    
    Write-Host $body
	
	
	Invoke-RestMethod -uri $uri -Method Post -body $body -ContentType 'application/json'

}

$Confirmation = ''
Write-Host "Je potrebne potvrdenie, ci su aplikacie deploynute ok pred nasadeim do produkcie."
While (-not($Confirmation)) {
    $Confirmation = Read-host -prompt 'Zadajte prosim "Y" pre pokracovanie nasadzovania...'
    if ($Confirmation -eq 'Y'){
        Write-Host "TEST"
        Send-TeamsMessage
    } else {
        Write-Host "K. Bye."
    }
}

