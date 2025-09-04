#---------------------------------------------------------------------------
# Controlled MDT deployment
#---------------------------------------------------------------------------


#---------------------------------------------------------------------------
# vSphere variables
$templateVM_OSName = "W7X86T1"
$templateVM_Name = "Win7-x86-ILIO-Template"
$vSphereTemplate = "ILIO_Win7_x86_Template"
$vCenterHost = "vcenter.home.stealthpuppy.com"
$vmHost = "hv2.home.stealthpuppy.com"
$vmDatastore = "ILIO_VirtualDesktops"
$vmCluster = "ILIO Cluster"
$vmFolder = "ILIO"

# Connect to VMware vCenter
Write-Verbose "Importing and configuring PowerCLI."
Add-PSSnapin "vmware.VimAutomation.core" -ErrorAction SilentlyContinue
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$False -DisplayDeprecationWarnings:$False
Write-Verbose "Getting credentials..."
$MyCredentials = Get-Credential 
Write-Verbose "Connecting to vSphere..."
Connect-VIServer -Server $vCenterHost -Credential $MyCredentials -Verbose

# Remove any existing VM
$targetVM = Get-VM | Where-Object { $_.Name -eq $templateVM_Name }
If ( $targetVM -ne $Null ) {
    Write-Verbose "Found existing VM: $targetVM.Name"
    If ( $targetVM.PowerState -eq "PoweredOn" ) { Stop-VM -VM $targetVM -Confirm:$False }
    Do {
        $targetVM = Get-VM | Where-Object { $_.name -eq $templateVM_Name }
        Switch ($TargetVM.PowerState) {
            { $_ -eq "PoweredOff" } { $Seconds = 0; break }
            { $_ -eq "PoweredOn" } { $Seconds = 10; break }
        }
        Start-Sleep $Seconds
    } Until ( $targetVM.PowerState -eq "PoweredOff" )
    Write-Verbose "Removing VM: $targetVM.Name"
    Remove-VM -VM $targetVM -DeletePermanently -Confirm:$False
}

# Create a VM from a template
Write-Verbose "Creating new VM..."
New-VM -VMHost $vmHost -Template $vSphereTemplate -Name $templateVM_Name -Datastore $vmDatastore -Location $vmFolder -Notes "MDT template VM"

# Get the target VM
Write-Verbose "Getting details for new VM."
$targetVM = Get-VM $templateVM_Name -Verbose

# Get the target VM"s UUID
Write-Verbose "Retrieving UUID for target VM."
$targetVMUUID = $targetVM | Get-vSphereVMUUID


#---------------------------------------------------------------------------
# MDT variables
$mdtBootISO = "[ISOs] LiteTouchPE_x86.iso"
$taskSequenceID = "W7ENT-X86"
$deploymentShare = "\\MDT1\Deployment"
$customSettingsINI = "$deploymentShare\Control\CustomSettings.ini"
$machineObjectOU = "OU=Workstations,DC=home,DC=stealthpuppy,DC=com"

# Connect to the MDT share
Write-Verbose "Connecting to MDT."
Add-PSSnapin "Microsoft.BDD.PSSNAPIN" -ErrorAction SilentlyContinue
If (!(Test-Path MDT:)) { New-PSDrive -Name MDT -Root $deploymentShare -PSProvider MDTPROVIDER }

# Write settings for the target VM to MDT CustomSettings.ini
# open INI file, create or edit section, assign task sequence, configure deployment wizard
Write-Verbose "Backing up CustomSettings.ini."
If (!(Test-Path "$deploymentShare\Control\CustomSettings-Backup.ini")) { Copy-Item $customSettingsINI "$deploymentShare\Control\CustomSettings-Backup.ini" -Force }

# Add a UUID entry from the target VM to CustomSettings.ini
Write-Verbose "Adding control section for $templateVM_Name."
$ini = Get-IniFile -FilePath $customSettingsINI
$ini.Add($TargetVMUUID, (New-Object System.Collections.Specialized.OrderedDictionary))
$ini.$TargetVMUUID.Add("OSDComputerName", $templateVM_OSName)
$ini.$TargetVMUUID.Add("TaskSequenceID", $taskSequenceID)
$ini.$TargetVMUUID.Add("MachineObjectOU", $machineObjectOU)
$ini.$TargetVMUUID.Add("WindowsUpdate", "FALSE")
$ini.$TargetVMUUID.Add("SkipSummary", "YES")
$ini.$TargetVMUUID.Add("SkipTaskSequence", "YES")
$ini.$TargetVMUUID.Add("SkipApplications", "YES")
$ini.$TargetVMUUID.Add("SkipLocaleSelection", "YES")
$ini.$TargetVMUUID.Add("SkipDomainMembership", "YES")
$ini.$TargetVMUUID.Add("SkipTimeZone", "YES")
$ini.$TargetVMUUID.Add("SkipComputerName", "YES")
$ini.$TargetVMUUID.Add("SkipUserData", "YES")
$ini.$TargetVMUUID.Add("SkipComputerBackup", "YES")
$ini.$TargetVMUUID.Add("SkipFinalSummary", "YES")
$ini.$TargetVMUUID.Add("FinishAction", "SHUTDOWN")
Write-Verbose "Writing to CustomSettings.ini."
$ini | Out-Ini -FilePath $customSettingsINI

# Clean up the MDT monitor data for the target VM if it exists
Write-Verbose "Clearing MDT monitor data."
Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $templateVM_OSName } | Remove-MDTMonitorData -Path MDT:


# Start the VM
Write-Verbose "Starting $templateVM_Name..."
If (!($TargetVM.PowerState -eq "PoweredOn")) { $targetVM | Start-VM -Verbose }

# Connect the MDT ISO to the target VM
Write-Verbose "Connecting MDT boot ISO to VM."
$CDDrives = $targetVM.CDDrives
Set-CDDrive -CD $CDDrives -StartConnected:$True -Connected:$True -Confirm:$False


# Wait for the OS deployment to start before monitoring
# This may require user intervention to boot the VM from the MDT ISO if an OS exists on the vDisk
If ((Test-Path variable:InProgress) -eq $True) { Remove-Variable -Name InProgress }
Do {
    $InProgress = Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $templateVM_OSName }
    If ($InProgress) {
        If ($InProgress.PercentComplete -eq 100) {
            $Seconds = 30
            $tsStarted = $False
            Write-Verbose "Waiting for task sequence to begin..."
        }
        Else {
            $Seconds = 0
            $tsStarted = $True
            Write-Verbose "Task sequence has begun. Moving to monitoring phase."
        }
    }
    Else {
        $Seconds = 30
        $tsStarted = $False
        Write-Verbose "Waiting for task sequence to begin..."
    }
    Start-Sleep -Seconds $Seconds
} Until ($TSStarted -eq $True)
 
# Monitor the MDT OS deployment once started
Write-Verbose "Waiting for task sequence to complete."
If ((Test-Path variable:InProgress) -eq $True) { Remove-Variable -Name InProgress }
Do {
    $InProgress = Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $templateVM_OSName }
    If ( $InProgress.PercentComplete -lt 100 ) {
        If ( $InProgress.StepName.Length -eq 0 ) { $StatusText = "Waiting for update" } Else { $StatusText = $InProgress.StepName }
        Write-Progress -Activity "Task sequence in progress" -Status $StatusText -PercentComplete $InProgress.PercentComplete
        Switch ($InProgress.PercentComplete) {
            { $_ -lt 25 } { $Seconds = 35; break }
            { $_ -lt 50 } { $Seconds = 30; break }
            { $_ -lt 75 } { $Seconds = 10; break }
            { $_ -lt 100 } { $Seconds = 5; break }
        }
        Start-Sleep -Seconds $Seconds
    }
} Until ($InProgress.CurrentStep -eq $InProgress.TotalSteps)
Write-Verbose "Task sequence complete."

# OS deployment is complete, ensure the target VM is shutdown
$targetVM = Get-VM | Where-Object { $_.Name -eq $templateVM_Name }
If ( $targetVM -ne $Null ) {
    # If ( $targetVM.PowerState -eq "PoweredOn" ) { Shutdown-VMGuest -VM $targetVM -Confirm:$False }
    Do {
        $targetVM = Get-VM | Where-Object { $_.name -eq $templateVM_Name }
        Switch ($TargetVM.PowerState) {
            { $_ -eq "PoweredOff" } { $Seconds = 0; break }
            { $_ -eq "PoweredOn" } { $Seconds = 10; break }
        }
        Start-Sleep $Seconds
    } Until ( $targetVM.PowerState -eq "PoweredOff" )
}


#---------------------------------------------------------------------------
# ILIO variables
$sshHost = "10.130.36.252"
$ilioStoragePath = "/exports/ILIO_VirtualDesktops"
$dnsDomain = $env:USERDNSDOMAIN.ToLower()

# Connect to the ILIO Session Host to run Fast Clone script
Import-Module SSH-Sessions
Write-Verbose "Connecting to ILIO Session Host."
New-SshSession -ComputerName $sshHost -Username "poweruser" -Password "poweruser"
Write-Verbose "Creating the AD configuration file."
Invoke-SshCommand -ComputerName $sshHost -Command "python /root/iliotools/python_tools/ad_gen.py $ilioStoragePath/$templateVM_Name/ $dnsDomain aaron K3lw4yP0c `"ou=Desktop Virtualization`""
Write-Verbose "Initiating Fast Clones..."
Invoke-SshCommand -ComputerName $sshHost -Command "/etc/ilio/create-fastclones.sh"
Remove-SshSession -RemoveAll
Write-Verbose "Fast Clones complete."
Start-Sleep 5


#---------------------------------------------------------------------------
# Import the newly cloned VMs into vCenter 
# http://www.wooditwork.com/2011/08/11/adding-vmx-files-to-vcenter-inventory-with-powercli-gets-even-easier/
foreach ($Datastore in Get-Datastore $vmDatastore) {
    Write-Verbose "Searching datastore for new VMs..."

    # Set up Search for .VMX Files in Datastore
    $ds = Get-Datastore -Name $Datastore | % { Get-View $_.Id }
    $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $SearchSpec.matchpattern = "*.vmx"
    $dsBrowser = Get-View $ds.browser
    $DatastorePath = "[" + $ds.Summary.Name + "]"
 
    # Find all .VMX file paths in Datastore, filtering out ones with .snapshot (Useful for NetApp NFS)
    $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | Where-Object { $_.FolderPath -notmatch ".snapshot" -and $_.FolderPath -notmatch $templateVM_Name } | % { $_.FolderPath + ($_.File | Select-Object Path).Path }
 
    #Register all .vmx Files as VMs on the datastore
    Write-Verbose "Adding VMs to inventory..."
    foreach ($VMXFile in $SearchResult) {
        New-VM -VMFilePath $VMXFile -VMHost $vmHost -Location $vmFolder -RunAsync
    }
}
Start-Sleep 2


#---------------------------------------------------------------------------
# XenDesktop variables
$adminAddress = "xd71.home.stealthpuppy.com"
$desktopCatalogName = "Windows 7 x86 ILIO"
$desktopGroupName = "Windows 7 ILIO"
$publishedDesktopName = "Windows 7 Desktop"
$timeZone = "GMT Standard Time"
$storageResource = "HV1-LocalStorage"
$hostingUnitPath = "XDHyp:\HostingUnits\UCS-vCenter-SSD"
$hostResource = "Lab SCVMM"
$hostConnectionPath = "XDHyp:\Connections\UCS-vCenter"

# Persistent VMs
$persistentTargetVMs = @{}
$persistentTargetVMs["W7PERS1"] = @("UCS-POC\W7PERS1", "UCS-POC\aaron")
$persistentTargetVMs["W7PERS2"] = @("UCS-POC\W7PERS2", "UCS-POC\aaron")
$persistentTargetVMs["W7PERS3"] = @("UCS-POC\W7PERS3", "UCS-POC\aaron")
$persistentTargetVMs["W7PERS4"] = @("UCS-POC\W7PERS4", "UCS-POC\aaron")
$persistentTargetVMs["W7PERS5"] = @("UCS-POC\W7PERS5", "UCS-POC\aaron")

# Add XenDesktop snap-ins
Write-Verbose "Adding XenDesktop PowerShell snapins."
Add-PSSnapin Citrix*

# Get XenDesktop hypervisor connection/host details
Write-Verbose "Getting XenDesktop hypervisor and connection details."
# $hostingUnit = Get-Item -AdminAddress $adminAddress -Path @($hostingUnitPath)
# $hostConnection = Get-Item -AdminAddress $adminAddress -Path @($hostConnectionPath)
$hostingUnit = Get-ChildItem -AdminAddress $adminAddress "XDHyp:\HostingUnits" | Where-Object { $_.PSChildName -like $storageResource } | Select-Object PSChildName, PsPath
$hostConnection = Get-ChildItem -AdminAddress $adminAddress "XDHyp:\Connections" | Where-Object { $_.PSChildName -like $hostResource } | Select-Object PSChildName, PsPath
$brokerHypConnection = Get-BrokerHypervisorConnection -AdminAddress $adminAddress -HypHypervisorConnectionUid $hostConnection.HypervisorConnectionUid
$brokerServiceGroup = Get-ConfigServiceGroup  -AdminAddress $adminAddress -ServiceType 'Broker' -MaxRecordCount 2147483647

# Create a new Desktop Catalog of type Existing
Write-Verbose "Creating XenDesktop catalog."
$brokerCatalog = New-BrokerCatalog -AdminAddress $adminAddress -AllocationType 'Permanent' -CatalogKind 'PowerManaged' -Name $desktopCatalogName

# Add machines to the catalog contained in the $persistentTargetVMs hashtable
Write-Verbose "Adding ILIO VMs to the catalog..."
$machineIDs = @()
ForEach ( $key in $persistentTargetVMs.Keys ) { 
    # Get target VM details from vSphere
    Write-Verbose "Adding VM: $key..."
    $targetVM = Get-ChildItem -Recurse -Path $hostConnection.PSPath | Where-Object { $_.Name -eq $key }

    # Create the machine in the target XD desktop catalog and grant access to a specific user
    $brokerMachine = New-BrokerMachine -AdminAddress $adminAddress -CatalogUid $brokerCatalog.Uid -HostedMachineId $targetVM.Id -HypervisorConnectionUid $brokerHypConnection.Uid -MachineName $persistentTargetVMs[$key][0]
    Add-BrokerUser -AdminAddress $adminAddress -Name $persistentTargetVMs[$key][1] -Machine $brokerMachine.Uid

    # Add the new machine IDs to an array
    $machineIDs += $brokerMachine.Uid
}
Write-Verbose "Desktop catalog complete."

# Create Desktop Group using the machines from the newly created catalog
Write-Verbose "Creating a Desktop Group and assigning VMs to users..."
$desktopGroup = New-BrokerDesktopGroup -AdminAddress $adminAddress -DesktopKind 'Private' -Name $desktopGroupName -OffPeakBufferSizePercent 10 -PeakBufferSizePercent 10 -PublishedName $publishedDesktopName -ShutdownDesktopsAfterUse $False -TimeZone $timeZone
Add-BrokerMachine -AdminAddress $adminAddress -InputObject @($machineIDs) -DesktopGroup $desktopGroupName
New-BrokerAccessPolicyRule -AdminAddress $adminAddress -AllowedConnections 'NotViaAG' -AllowedProtocols @('RDP', 'HDX') -AllowedUsers 'AnyAuthenticated' -AllowRestart $True -Enabled $True -IncludedDesktopGroupFilterEnabled $True -IncludedDesktopGroups @($desktopGroupName) -IncludedSmartAccessFilterEnabled $True -IncludedUserFilterEnabled $True -Name "$($desktopGroupName)_Direct"
New-BrokerAccessPolicyRule -AdminAddress $adminAddress -AllowedConnections 'ViaAG' -AllowedProtocols @('RDP', 'HDX') -AllowedUsers 'AnyAuthenticated' -AllowRestart $True -Enabled $True -IncludedDesktopGroupFilterEnabled $True -IncludedDesktopGroups @($desktopGroupName) -IncludedSmartAccessFilterEnabled $True -IncludedSmartAccessTags @() -IncludedUserFilterEnabled $True -Name "$($desktopGroupName)_AG"
New-BrokerPowerTimeScheme -AdminAddress $adminAddress -DaysOfWeek 'Weekdays' -DesktopGroupUid $desktopGroup.Uid -DisplayName 'Weekdays' -Name "$($desktopGroupName)_Weekdays" -PeakHours @($False, $False, $False, $False, $False, $False, $False, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $False, $False, $False, $False, $False) -PoolSize @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
New-BrokerPowerTimeScheme -AdminAddress $adminAddress -DaysOfWeek 'Weekend' -DesktopGroupUid $desktopGroup.Uid -DisplayName 'Weekend' -Name "$($desktopGroupName)_Weekend" -PeakHours @($False, $False, $False, $False, $False, $False, $False, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $True, $False, $False, $False, $False, $False) -PoolSize @(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

Write-Verbose "Deployment complete."