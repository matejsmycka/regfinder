Start-Job -ScriptBlock {
	start "C:\pcsm\pcsm.exe"
}
Add-Type -AssemblyName System.Windows.Forms
$form = New-Object Windows.Forms.Form
$form.Size = New-Object Drawing.Size @(600,300)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "none"
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Size(240,140)
$Label.Text = "Načítavanie údajov..."
$Label.AutoSize = $True
$form.Controls.Add($Label)
$form.Show()
Start-Sleep -Seconds 15
$form.Close()