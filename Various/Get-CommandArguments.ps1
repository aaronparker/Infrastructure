$a = Get-Command New-BrokerDesktopGroup
$a.ParameterSets[0] | select -ExpandProperty parameters | ft name, ismandatory, aliases

