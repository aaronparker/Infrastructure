# Authenticate to the remote host (CredSSP already configured for workgroup machines)
$Username = "Administrator"
$Password = "Passw0rd"
$SPassword = convertto-securestring -String $Password -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SPassword
# $cred = Get-Credential -UserName Administrator -Message "Please enter the password."
$nuc1 = New-CimSession -Credential $cred -ComputerName nuc1

Add-DnsServerPrimaryZone -CimSession $nuc1 -ZoneFile home.stealthpuppy.com.dns -Name home.stealthpuppy.com -LoadExisting
Add-DnsServerPrimaryZone -CimSession $nuc1 -ZoneFile _msdcs.home.stealthpuppy.com.dns -Name _msdcs.home.stealthpuppy.com -LoadExisting
Add-DnsServerPrimaryZone -CimSession $nuc1 -ZoneFile 0.168.192.in-addr.arpa.dns -Name 0.168.192.in-addr.arpa -LoadExisting
