# Get a VM 
$hvHost = "hv1.home.stealthpuppy.com"
Get-VM -ComputerName $hvHost

# Remove a virtual hard disk
$VHD = Get-VMHardDiskDrive -ComputerName $hvHost -VMName xd71
Get-VM -ComputerName $hvHost -Name xd71 | Remove-VM -Force
Invoke-Command -ComputerName $hvHost { Remove-Item "C:\Users\Public\Documents\Hyper-V\Virtual Hard Disks\XD71.vhdx" }


# Create a VM
$vmName = "APPV1"
$bootISO = "D:\MDT\Automata\Boot\LiteTouchPE_x64.iso"
$switchName = "External Ethernet"
$vhdPath = (Get-VMHost -ComputerName $hvHost).VirtualHardDiskPath
New-VM -ComputerName $hvHost -Generation 2 –Name $vmName -SwitchName $switchName –MemoryStartupBytes 768MB -NewVHDSizeBytes 64GB -NewVHDPath "$VHDPath\$vmName.vhdx" -Verbose
$dvdDrive = Get-VMDvdDrive -ComputerName $hvHost -VMName $vmName
$vhdDrive = Get-VHD -ComputerName $hvHost -VMName $vmName
Set-VMDvdDrive -ComputerName $hvHost -VMName $vmName -Path $bootISO -Verbose
Set-VMFirmware -ComputerName $hvHost -VMName $vmName -FirstBootDevice $dvdDrive -Verbose
Set-VM -ComputerName $hvHost -Name $vmName -ProcessorCount 2 -AutomaticStartAction Nothing -AutomaticStopAction Shutdown -DynamicMemory -Verbose
Get-VMScsiController -ComputerName $hvHost -VMName $vmName | Add-VMDvdDrive -Path $bootISO
Get-VM -ComputerName $hvHost -VMName $vmName | Add-VMDvdDrive -Path $bootISO

# Set all VM DVD drives to nothing
Get-VM | Get-VmDvdDrive | ForEach { Set-VMDvdDrive -Path $Null }