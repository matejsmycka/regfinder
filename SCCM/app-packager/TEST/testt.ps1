<#$ApplicationName = "TEST-Google Chrome"
$Global:SCCMAccount = "UCN\rosinecadm"
$ApplicationVersion = "66.0.3359.139"
$DepTypeDeploymentTypeName = "x86"

set-location MU1:

$Superseded	= Get-CMDeploymentType -ApplicationName $(Get-CMApplication | Where {$_.LocalizedDisplayName -match $ApplicationName -and $_.CreatedBy -eq $Global:SCCMAccount -and $_.SoftwareVersion -lt $ApplicationVersion -and $_.IsSuperseded -eq $False}).LocalizedDisplayName | Where {$_.LocalizedDisplayName -Match $DepTypeDeploymentTypeName}
$Superseding = Get-CMDeploymentType -ApplicationName $(Get-CMApplication | Where {$_.LocalizedDisplayName -match $ApplicationName -and $_.CreatedBy -eq $Global:SCCMAccount -and $_.SoftwareVersion -eq $ApplicationVersion}).LocalizedDisplayName | Where {$_.LocalizedDisplayName -Match $DepTypeDeploymentTypeName}

Write-Output $Superseded
Write-Output $Superseding

Add-CMDeploymentTypeSupersedence -SupersededDeploymentType $Superseded -SupersedingDeploymentType $Superseding

set-location C:


Get-CMDeploymentType -ApplicationName $(Get-CMApplication | Where {$_.LocalizedDisplayName -match "TEST-Google Chrome" -and $_.SoftwareVersion -lt "66.0.3359.139"}).LocalizedDisplayName | Where {$_.LocalizedDisplayName -Match "x86" -and $_.IsSuperseded -eq $False}

$Message = "V centralnej správe prebehla aktualizacia nasledujucich aplikacii. `n"

$Message += "_______________________________________________________`n"
$Message += "Prosíme o kontrolu tychto aplikácií a v prípade akýchkoľvek problémov nás kontaktovali odpoveďou na tuto spravu.`n"
$Message += "Zamerajte sa prosím hlavne na tieto body:`n"
$Message += "   - Centrum softwaru uspesne nainstalovalo aplikaciu na danu verziu.`n"
$Message += "   - Aplikacia je po aktualizacii na danej verzii`n"
$Message += "   - Aplikacia si zachovala svoju funkcnost.`n`n"
$Message += "S pozdravom,`n~Aktualizator [winadm@ics.muni.cz]"

Send-MailMessage -To "rosinec@ics.muni.cz" -Subject "Encoding TEST" -From "Aktualizator <rosinec@ics.muni.cz>" -Body $Message -SmtpServer "relay.muni.cz" -Encoding "UTF8" -ErrorAction Stop
#>

$uri = "https://outlook.office.com/webhook/91765e2f-4b98-4ef7-8b70-4be4efa3dc0d@11904f23-f0db-4cdc-96f7-390bd55fcee8/IncomingWebhook/fd30748fd5da4fc3b628066f0edcd6bf/7d2da52d-357e-408b-a9be-52bf1cab5332"

$body = ConvertFrom-Json '{"type":"AdaptiveCard","body":[{"type":"Container","items":[{"type":"TextBlock","size":"Large","weight":"Bolder","text":"Aktualizacie Softwaru"},{"type":"TextBlock","spacing":"Small","separator":true,"text":"V centralnej správe boli aktualizované nasledujúce aplikácie"}]},{"type":"Container","items":[{"type":"TextBlock","text":"","wrap":true}]},{"type":"Container","items":[{"type":"TextBlock","separator":true,"color":"Accent","text":"V pripade problemov prosim vyuzite toto vlakno."}]}],"actions":[{"type":"Action.ShowCard","title":"Prijemnejsi den?","card":{"type":"AdaptiveCard","style":"emphasis","body":[{"type":"Image","url":"https://cataas.com/cat/cute"}],"$schema":"http://adaptivecards.io/schemas/adaptive-card.json"}}],"$schema":"http://adaptivecards.io/schemas/adaptive-card.json","version":"1.0"}'
#@(@{type="TextBlock";text="ASDASDASDASDASD";wrap= "True"})
$body = ConvertFrom-Json '{"@type": "MessageCard", "@context": "https://schema.org/extensions", "summary": "Aktualizacie softwaru", "themeColor": "0000dc", "title": "Aktualizacie softwaru", "sections": [ { "title": "V centralnej sprave boli aktualizovane nasledujuce aplikacie." }, { "text": "" }, { "text": "V pripade problemov prosim vyuzite toto vlakno." } ] }'
$body.sections[1].text = "- TEST`n- TEST`n- TEST`n"

$new = '{ "contentType": "application/vnd.microsoft.card.adaptive", "type": "AdaptiveCard", "version": "1.0", "body": [ { "type": "TextBlock", "text": "Default" } ], "actions": [{ "type": "Action.Submit", "title": "OK" }] }'

$body = ConvertTo-Json -Depth 4 $body
Invoke-RestMethod -uri $uri -Method Post -body $new -ContentType 'application/json'
