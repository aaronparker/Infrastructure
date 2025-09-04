# http://windowsitpro.com/windows-server-2012/controlling-windows-firewall-powershell

# Allow everything inbound and outbound without disabling Windows Firewall
Set-NetFirewallProfile -all -DefaultInboundAction Allow -DefaultOutboundAction Allow