# Authenticate to the remote host (CredSSP already configured for workgroup machines)
$Username = "Administrator"
$Password = "password"
$SPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $SPassword
# $cred = Get-Credential -UserName Administrator -Message "Please enter the password."
$nuc1 = New-CimSession -Credential $cred -ComputerName nuc1.home.stealthpuppy.com

# Get configuration from remote host
$VmHost = Get-VMHost -CimSession $nuc1 | select * | Format-List
$VmHost.VirtualHardDiskPath
$VmHost.VirtualMachinePath

# Get configuration from a VM
$VM = Get-VM -CimSession $nuc1 -Name DC1 | select Path, ConfigurationLocation, CheckpointFileLocation, SmartPagingFilePath, SnapshotFileLocation
$VM.CheckpointFileLocation
$VM.ConfigurationLocation
$VM.SmartPagingFilePath
$VM.SnapshotFileLocation
$VM.Path

# View path properties on all VMs
Get-Vm -CimSession $nuc1 | select Name, Path, ConfigurationLocation, CheckpointFileLocation, SmartPagingFilePath, SnapshotFileLocation


# Set default folders
Machines
Virtual Hard Disks
Checkpoints
Smart Paging File

# Set all DVD drives on a VM to 'None'
Get-VMDvdDrive -CimSession $nuc1 -VMName DC1 | foreach { Set-VMDvdDrive -VMDvdDrive $_ -Path $Null }

# Move all VMs where XML configuration is stored in specific location to new location, on a remote Hyper-V host.
Get-VM -CimSession $nuc1 | Where-Object { $_.ConfigurationLocation -eq "D:\Hyper-V\Machines" } | Move-VMStorage -VirtualMachinePath D:\Hyper-V -Verbose

# Set Checkpoints and Smart Paging locations on all VMs except for DC1 on a remote Hyper-V host.
Get-VM -CimSession $nuc1 | Where-Object { $_.Name -ne "DC1" } | Set-VM -SnapshotFileLocation "D:\Hyper-V" -SmartPagingFilePath "C:\Hyper-V" -Verbose