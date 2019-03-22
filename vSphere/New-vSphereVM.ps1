# Load the PowerCLI module
Add-PSSnapin "vmware.VimAutomation.core" -ErrorAction SilentlyContinue
If ((Get-PSSnapin -Registered | Where-Object { $_.Name -eq "VMware.DeployAutomation" }) -eq $null)
{
    Exit 1
}

# Configure this PowerCLI session
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$False -DisplayDeprecationWarnings:$False

$vCenterHost = "vcenter.home.stealthpuppy.com"
$vmHost = "hv2.home.stealthpuppy.com"
$dataStore = "ILIO_Diskbacked"
$isoPath = "[OCZ Vertex3] ISOs/LiteTouchPE_x86.iso"
$folderLocation = "Others"
$diskSize = 32
$diskStorageFormat = "Thin"
$vCPU = 2
$vRAM = 2
$hardwareVersion = "v8"

# Get credentials for vCenter and connect
# $MyCredentials = Get-Credential
# Connect-VIServer -Server $vCenterHost -Credential $MyCredentials -Verbose
Connect-VIServer -Server $vCenterHost -User root -Password vmware -Verbose

# Get virtual machine network
$vmNetwork = Get-VirtualPortGroup | Where-Object { $_.Name -like "*VM Network*" }

$vmName = Read-Host -Prompt "Enter VM name"

# Create a new virtual machine
$vm = New-VM -VMHost $vmHost -CD -Datastore $dataStore -DiskGB $diskSize -DiskStorageFormat $diskStorageFormat -Location $folderLocation -MemoryGB $vRAM -Name $vmName -NetworkName $vmNetwork.Name -NumCpu $vCPU -Version $hardwareVersion

# Add the MDT boot ISO to the new VM
$vm | Get-CDDrive | Set-CDDrive -IsoPath $isoPath -StartConnected:$True -Confirm:$False

# Change the network adapter type to VMXNET3
$vm | Get-NetworkAdapter | Set-NetworkAdapter -Type Vmxnet3 -NetworkName $vmNetwork.Name -Confirm:$False

# Change the SCSI adapter to paravirtualized for better performance
$vm | Get-ScsiController | Set-ScsiController -Type ParaVirtual -Confirm:$False

# Set the OS guest type
$vm | Set-VM -GuestId Windows8Guest -Confirm:$False