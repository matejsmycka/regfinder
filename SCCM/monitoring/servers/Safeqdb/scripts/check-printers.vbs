option explicit

Dim intPodezrelyPocetUloh
intPodezrelyPocetUloh = 10

Dim intReturnStatus
intReturnStatus = 0

'
''''''''''''' zkontrolovat parametry '''''''''''''''''
'
'If Wscript.Arguments.Count <> 1 Then
'  WScript.Echo "check-printer.vbs: zadejte jako jediny parametr jmeno tiskarny"
'  WScript.Quit 3
'End If

Dim strPrinterName, strQueryPrintJobs, intPrintJobs, strProblematicPrinters
Dim objWMIService, objPrintJobs, objPrintJob

'strPrinterName = WScript.Arguments(0)

'
'''''''''''' verify that spooler is running '''''''''''''
'
Dim colServiceList, objservice

Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
Set colServiceList = objWMIService.ExecQuery ("Select * from Win32_Service WHERE Name = 'spooler'")
For Each objservice in colServiceList
	If objService.State <> "Running" Then
		WScript.Echo 'Tiskovy spooler je vyply, na zadnou z tiskaren nepujde nic poslat."
		WScript.Quit 2
	End If
Next

'
'''''''''''' verify that printer exists ''''''''''''''''
'
Dim objPrinters, objPrinter, strQueryPrinter, intPrinters
strQueryPrinter = "SELECT * FROM Win32_Printer"

Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
Set objPrinters  = objWMIService.ExecQuery( strQueryPrinter )
intPrinters = 0
For Each objPrinter In objPrinters
	intPrinters = intPrinters + 1
	strPrinterName = objPrinter.Name

	strQueryPrintJobs = "SELECT * FROM Win32_PrintJob WHERE Name LIKE '" & strPrinterName & ", %'"
	'WScript.Echo strQueryPrintJobs

	Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
	Set objPrintJobs  = objWMIService.ExecQuery( strQueryPrintJobs )
	If Err Then Syntax "No matching printer found"

	intPrintJobs = 0
	For Each objPrintJob In objPrintJobs  
		intPrintJobs = intPrintJobs + 1
	Next

	'''''''''''''''' evaluate results ''''''''''''''''''''
	If intPrintJobs >= intPodezrelyPocetUloh Then
		strProblematicPrinters = strProblematicPrinters & " " & strPrinterName & " (" & intPrintJobs & " uloh), "
		intReturnStatus = 1
	End If
	'WScript.Echo strPrinterName & " " & intPrintJobs

Next

'
'''''''''''''''' evaluate results ''''''''''''''''''''
'
If intReturnStatus = 0 Then
	WScript.Echo "Vsechny tiskarny vypadaji v poradku"
Else
	WScript.Echo "Tyto tiskarny maji vice nez " & (intPodezrelyPocetUloh - 1) & " uloh v tiskove fronte: " & strProblematicPrinters 
End If

WScript.Quit intReturnStatus