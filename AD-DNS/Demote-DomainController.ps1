#
# Windows PowerShell script for AD DS Deployment
#

Import-Module ADDSDeployment
Uninstall-ADDSDomainController `
-DemoteOperationMasterRole:$true `
-DnsDelegationRemovalCredential (Get-Credential) `
-IgnoreLastDnsServerForZone:$true `
-RemoveDnsDelegation:$true `
-RemoveApplicationPartitions:$true `
-IgnoreLastDCInDomainMismatch:$true `
-Force:$true

