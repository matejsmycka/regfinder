'===============================================================
'
' - je potreba spoustet prikazem "cscript /nologo script_name.vbs"
'
'===============================================================

'---------------------------------------------------------------
' Konstanty
'---------------------------------------------------------------

Const ForReading = 1
Const UnknownStatus = 2

'---------------------------------------------------------------
' Nacteni souboru s XML
'---------------------------------------------------------------

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.OpenTextFile ("./scripts/GISMapService_zdroj.txt", ForReading)
	strLine = objFile.ReadLine
objFile.Close

'---------------------------------------------------------------
' Vytvoreni requestu
'---------------------------------------------------------------

Set xmlhttp = CreateObject("Microsoft.XMLHTTP")
xmlhttp.open "POST", "http://maps.muni.cz/ArcGIS/services/studovny/MapServer",False
xmlhttp.setRequestHeader "Content-Type", "text/xml"
xmlhttp.send(strLine)

'---------------------------------------------------------------
' Odpoved na request
'---------------------------------------------------------------

strResponse = xmlhttp.responseText
strInterest = Mid(strResponse,InStr(strResponse,"<Result>")+8,1)

'---------------------------------------------------------------
' Interpretace vystupu
'---------------------------------------------------------------

if (IsNumeric(strInterest)) then
	' v poradku ziskany vystup
        Wscript.StdOut.WriteLine "Mapova sluzba funguje spravne"
	wscript.quit(0)
else
	Wscript.StdOut.WriteLine "Webova sluzba je dostupna, ale placa nesmysly"
        Wscript.StdOut.Write strResponse
        Wscript.StdOut.WriteLine "Bla"	
        wscript.quit(UnknownStatus)
end if
