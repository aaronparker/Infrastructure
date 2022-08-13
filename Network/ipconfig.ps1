# https://blogs.technet.microsoft.com/josebda/2015/04/18/windows-powershell-equivalents-for-common-networking-commands-ipconfig-ping-nslookup/

Get-NetIPConfiguration
Get-NetIPAddress | Sort InterfaceIndex | ft InterfaceIndex, InterfaceAlias, AddressFamily, IPAddress, PrefixLength -AutoSize
Get-NetIPAddress | ? AddressFamily -EQ IPv4 | ft –AutoSize
Get-NetAdapter Wi-Fi | Get-NetIPAddress | ft -AutoSize