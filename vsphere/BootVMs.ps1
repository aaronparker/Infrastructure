$VIServer = "10.130.36.222"
Add-PSSnapin 'vmware.VimAutomation.core'
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$False
$MyCredentials = Get-Credential
Connect-VIServer -Server $VIServer -Credential $MyCredentials -Verbose

If (!($TargetVM.PowerState -eq "PoweredOn")) { $TargetVM | Start-VM -Verbose }

$VMs = Get-VM | Where-Object { $_.Name -like "ILIO-EX*" }
ForEach ( $VM in $VMs ) { 
    If ( $VM.PowerState -eq "PoweredOff" ) { $VM | Start-VM -Verbose -RunAsync }
}
