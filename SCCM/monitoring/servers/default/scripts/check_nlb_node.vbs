
' Wscript.Stdout.Write

Dim strComputerName, StateValue, RetCode, wshNetwork

Set wshNetwork = WScript.CreateObject( "WScript.Network" )
strComputerName = wshNetwork.ComputerName

'strComputer = "."
RetCode = 0


StateValue = NodeStatus(strComputerName)
select case StateValue
  case 0    
    wscript.echo "The StatusCode value cannot be retrieved from the node."
    RetCode = 2
  case 1000    
    wscript.echo "Success."
  case 1001    
    wscript.echo "Cluster mode is already stopped/started, or traffic handling is already" &_
    " enabled/disabled on specified port."
    RetCode = 2
  case 1002    
    wscript.echo "Cluster mode stop or start operation interrupted connection draining process."
    RetCode = 2
  case 1003    
    wscript.echo "Cluster mode could not be started due to configuration problems on the target host."
    RetCode = 2
  case 1004    
    wscript.echo "Port number not found among port rules."
    RetCode = 2
  case 1005    
    wscript.echo "Cluster mode is stopped on the host."
    RetCode = 2
  case 1006    
    wscript.echo "Cluster is converging."
    RetCode = 2
  case 1007    
    wscript.echo "Cluster or host converged successfully."
  case 1008    
    wscript.echo "Host is converged as default host."
  case 1009    
    wscript.echo "Host is draining after drainstop command."
    RetCode = 2
  case 1013    
    wscript.echo "Cluster operations have been suspended on the host."
    RetCode = 2
  case else:
    wscript.echo "Unknown state."
    RetCode = 2
end select
Wscript.Echo "Status code: " & StateValue


' Finish
WScript.Quit(RetCode)


Function NodeStatus(byVal strComputer)
  Dim objWMIService, colItems, objItem

  Set objWMIService = GetObject("winmgmts:\\"  & strComputer & "\root\MicrosoftNLB")
  Set colItems = objWMIService.ExecQuery("select * from MicrosoftNLB_Node")

  NodeStatus = 0
  For Each objItem in colItems
    'Wscript.Echo objItem.ComputerName
    If InStr(1, objItem.ComputerName, strComputer, 1) = 1 Then
      'Wscript.Echo "Bingo"
      NodeStatus = objItem.StatusCode
    End If
  Next

  Set objWMIService = Nothing

end function

