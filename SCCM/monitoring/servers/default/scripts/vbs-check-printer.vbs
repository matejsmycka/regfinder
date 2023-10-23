option explicit

Dim intPodezrelyPocetUloh
intPodezrelyPocetUloh = 10

'
''''''''''''' zkontrolovat parametry '''''''''''''''''
'
If Wscript.Arguments.Count <> 1 Then
  WScript.Echo "check-printer.vbs: zadejte jako jediny parametr jmeno tiskarny"
  WScript.Quit 3
End If

Dim strPrinterName, strQueryPrintJobs, intPrintJobs
Dim objWMIService, objPrintJobs, objPrintJob

strPrinterName = WScript.Arguments(0)

'
'''''''''''' verify that spooler is running '''''''''''''
'
Dim colServiceList, objservice

Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
Set colServiceList = objWMIService.ExecQuery ("Select * from Win32_Service WHERE Name = 'spooler'")
For Each objservice in colServiceList
	If objService.State <> "Running" Then
		WScript.Echo 'Tiskovy spooler je vyply, na tiskarnu ' & strPrinterName & " nepujde nic poslat."
		WScript.Quit 2
	End If
Next

'
'''''''''''' verify that printer exists ''''''''''''''''
'
Dim objPrinters, objPrinter, strQueryPrinter, intPrinters
strQueryPrinter = "SELECT * FROM Win32_Printer WHERE Name LIKE '" & strPrinterName & "%'"

Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
Set objPrinters  = objWMIService.ExecQuery( strQueryPrinter )
intPrinters = 0
For Each objPrinter In objPrinters
	intPrinters = intPrinters + 1
	strPrinterName = objPrinter.Name
Next

If intPrinters <> 1 Then
	WScript.Echo "Z parametru " & WScript.Arguments(0) & " se nepovedlo jednoznacne urcit tiskarnu"
	WScript.Quit 3
End If

'
'''''''''''' count printjobs ''''''''''''''''''''''''
'
strQueryPrintJobs = "SELECT * FROM Win32_PrintJob WHERE Name LIKE '" & strPrinterName & ", %'"
'WScript.Echo strQueryPrintJobs

Set objWMIService = GetObject( "winmgmts:\\.\root\CIMV2" )
Set objPrintJobs  = objWMIService.ExecQuery( strQueryPrintJobs )
If Err Then Syntax "No matching printer found"

intPrintJobs = 0
For Each objPrintJob In objPrintJobs  
	intPrintJobs = intPrintJobs + 1
Next

'
'''''''''''''''' evaluate results ''''''''''''''''''''
'
If intPrintJobs < intPodezrelyPocetUloh Then
	WScript.Echo "Tiskarna " & strPrinterName & " vypada v poradku, ve fronte je " & intPrintJobs & " uloh."
	WScript.Quit 0
Else
	WScript.Echo "Tiskarna " & strPrinterName & " vypada divne, ve fronte je " & intPrintJobs & " uloh."
	WScript.Quit 1
End If
