# Having issues with New-LABVM.ps1 function, this script for testing / troubleshooting

Function New-LabVM {
        
    $VmHost = Get-VMHost -ComputerName "nuc1.home.stealthpuppy.com" -ErrorAction "Stop"
    $VmNetwork = $VmHost | Select-Object -ExpandProperty ExternalNetworkAdapters
    $memoryStartupBytes = 768MB
    $newVHDSizeBytes = 64GB
    $isoPath = "C:\ISOs\LiteTouchPE_x64.iso"
    $bootDevice = "CD"
    $SnapshotFileLocation = "D:\Hyper-V\Snapshots"
    $SmartPagingFilePath = "C:\Hyper-V"
    $Name = "TEST1"
    $Generation = 2

    $Params = @{
        Name               = $Name
        MemoryStartupBytes = $memoryStartupBytes
        # NewVHDSizeBytes = $newVHDSizeBytes
        # NewVHDPath = $VmHost.VirtualHardDiskPath + "\$Name.vhdx"
        SwitchName         = $VmHost.ExternalNetworkAdapters[0].SwitchName
        Generation         = $Generation
        BootDevice         = $bootDevice
    }

    # Create the new virtual machine
    $VHD = New-VHD -Path "D:\Hyper-V\Virtual Hard Disks\TEST1.vhdx" -SizeBytes $newVHDSizeBytes -Dynamic -ComputerName $VmHost.Name -Verbose
    $VM = New-VM -Name $Name -MemoryStartupBytes 768MB -SwitchName "VM External Network" -Generation 2 -BootDevice "CD" -VHDPath "D:\Hyper-V\Virtual Hard Disks\TEST1.vhdx" -ComputerName $VmHost.Name -Verbose

    # Set additional VM properties
    $VM | Set-VM -ProcessorCount $CPUs -AutomaticStartAction Nothing -AutomaticStopAction Shutdown -DynamicMemory -Verbose
    $VM | Set-VM -SnapshotFileLocation $SnapshotFileLocation -SmartPagingFilePath $SmartPagingFilePath
    $VM | Get-VMDvdDrive | Set-VMDvdDrive -Path $isoPath
    $DVD = ($VM | Get-VMDvdDrive)
        
}