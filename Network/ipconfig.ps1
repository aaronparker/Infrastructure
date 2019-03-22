# https://blogs.technet.microsoft.com/josebda/2015/04/18/windows-powershell-equivalents-for-common-networking-commands-ipconfig-ping-nslookup/

Get-NetIPConfiguration
Get-NetIPAddress | Sort InterfaceIndex | FT InterfaceIndex, InterfaceAlias, AddressFamily, IPAddress, PrefixLength -Autosize
Get-NetIPAddress | ? AddressFamily -eq IPv4 | FT –AutoSize
Get-NetAdapter Wi-Fi | Get-NetIPAddress | FT -AutoSize