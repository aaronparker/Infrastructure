# Get physical network adapters from Intel
$NetAdapter = Get-NetAdapter | Where-Object {$_.ifDesc -Like "Intel*" } | Select *

# Get IPv4 IP Address of interface with adapter set to DHCP 
$InfIPv4 = Get-NetIPAddress | Where-Object { $_.InterfaceAlias -eq (Get-NetIPInterface | Where-Object { $_.AddressFamily -eq "IPv4" -and $_.Dhcp -eq "Enabled" } | Select *).InterfaceAlias } | Where-Object { $_.AddressFamily -eq "IPv4" }

Set-NetIPAddress -InterfaceAlias $InfIPv4.InterfaceAlias -IPAddress 192.168.0.6 -AddressFamily IPv4 -PrefixLength 24 -Confirm:$False -Verbose
New-NetIPAddress -InterfaceAlias $InfIPv4.InterfaceAlias -IPAddress 192.168.0.6 -DefaultGateway 192.168.0.1 -AddressFamily IPv4 -PrefixLength 24 -Confirm:$False -Verbose

Set-DnsClientServerAddress -InterfaceAlias $InfIPv4.InterfaceAlias -ServerAddresses 127.0.0.1 -Confirm:$False -Verbose


