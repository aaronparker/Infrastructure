# Install Active Directory role
Install-windowsfeature AD-domain-services


# Install DC into existing domain
Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-Credential (Get-Credential) `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainName "home.stealthpuppy.com" `
-InstallDns:$false `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-ReplicationSourceDC "HV1.home.stealthpuppy.com" `
-SiteName "Home" `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true


# Install DC into existing domain
Import-Module ADDSDeployment
Install-ADDSDomainController `
-NoGlobalCatalog:$false `
-CreateDnsDelegation:$false `
-Credential (Get-Credential) `
-CriticalReplicationOnly:$false `
-DatabasePath "C:\windows\NTDS" `
-DomainName "home.stealthpuppy.com" `
-InstallDns:$true `
-LogPath "C:\windows\NTDS" `
-NoRebootOnCompletion:$false `
-SiteName "Home" `
-SysvolPath "C:\windows\SYSVOL" `
-Force:$true

# Install first DC into new forest
$Password = "Passw0rd"
$SPassword = convertto-securestring -String $Password -AsPlainText -Force

Install-ADDSForest -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -DomainMode "Win2012R2" -DomainName "home.stealthpuppy.com" -DomainNetbiosName "home" -ForestMode "Win2012R2" -InstallDns:$false -LogPath "C:\Windows\NTDS" -NoRebootOnCompletion:$true -SysvolPath "C:\Windows\SYSVOL" -SafeModeAdministratorPassword $SPassword  -Force:$true