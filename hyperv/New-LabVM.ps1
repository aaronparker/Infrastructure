Function New-LabVM {
    <#
        .SYNOPSIS
            Creates a new VM configured for the lab environment.
 
        .DESCRIPTION
            Creates a new VM specifically configured for my home lab environment.
            Create v1 or v2 VMs and configure VM for specific paths on the host machine.

        .PARAMETER Name
            Specify the name of the virtual machine.
            
        .PARAMETER CPUs
            Specify the number of vCPUs to configure the machine with. Will default to 2 vCPUs.
            No more than 2 vCPUs will be accepted to ensure the host is not overcommited.
            
        .PARAMETER VHDSize
            Specify the size of the VHDX in GB assigned to the VM. Will default to 64 GB.
            Sizes between 32 and 128 GB will be accepted.
            
        .PARAMETER Host
            Specify the target host. Will default to NUC1.
            
        .PARAMETER Generation
            Specify the version of the VM to use. Will default to generation 2 VMs.
            Values of 1 and 2 are accepted.
              
        .EXAMPLE
            PS C:\> New-LabVM -Name APPV1 -CPUs 2 -VHDSize 64
 
        .NOTES
 	        NAME: New-LabVM.ps1
	        VERSION: 1.0
	        AUTHOR: Aaron Parker
	        LASTEDIT: April 06, 2016
 
        .LINK
            http://stealthpuppy.com
    #>
    [CmdletBinding (SupportsShouldProcess = $False, ConfirmImpact = "Low", DefaultParameterSetName = "")]
    PARAM (
        [Parameter (Mandatory = $True, Position = 0, ValueFromPipeline = $True, HelpMessage = "Specify a name for the virtual machine.")]
        [alias("VMName")]
        [string]$Name,
        
        [Parameter (Mandatory = $False, HelpMessage = "Specify the host where the new virtual machine will be created.")]
        [alias("ComputerName")]
        [string]$VmHost = "nuc1.home.stealthpuppy.com",
        
        [Parameter (Mandatory = $False, HelpMessage = "Specify the number of vCPUs to be assigned to the virtual machine.")]
        [alias("ProcessorCount")]
        [ValidateSet(1, 2)][int]$CPUs = 2,

        [Parameter (Mandatory = $False, HelpMessage = "Specify the size of the virtual hard disk assigned to the virtual machine.")]
        [ValidateRange(32, 128)][int]$VHDSize = 64,

        [Parameter (Mandatory = $False, HelpMessage = "Specify the virtual machine generation.")]
        [alias("Version")]
        [ValidateSet(1, 2)]$Generation = 2
    )
    
    BEGIN {        
        Try {
            
            # See if a CIM session to the specified host exists
            $CimSession = Get-CimSession | Where-Object { $_.ComputerName -eq $VMHost } 
            If ( $CimSession ) {

                # If a CIM session to the host exists, use that for authentication and connect to host
                $oVmHost = Get-VMHost -CimSession $CimSession -ErrorAction "Stop"
            }
            Else {
                
                # If no CIM session exists, assume pass-through authentication will work and connect to host
                $oVmHost = Get-VMHost -ComputerName $VMHost -ErrorAction "Stop"   
            }
        }

        Catch {
            Write-Error "Error acessing host $VMHost $($_.Exception.Message)"
        }
                
        # $VmNetwork = $oVmHost | Select-Object -ExpandProperty ExternalNetworkAdapters
        $memoryStartupBytes = 768MB
        $newVHDSizeBytes = 64GB
        $isoPath = "C:\ISOs\LiteTouchPE_x64.iso"
        $bootDevice = "CD"
        $SnapshotFileLocation = "D:\Hyper-V\Snapshots"
        $SmartPagingFilePath = "C:\Hyper-V"
    }

    PROCESS {

        $Params = @{
            Name               = $Name
            MemoryStartupBytes = $memoryStartupBytes
            # NewVHDSizeBytes = $newVHDSizeBytes
            # NewVHDPath = $oVmHost.VirtualHardDiskPath + "\$Name.vhdx"
            SwitchName         = $oVmHost.ExternalNetworkAdapters[0].SwitchName
            Generation         = $Generation
            BootDevice         = $bootDevice
        }

        # Create the new virtual machine
        If ( $CimSession ) {
            Write-Host "CIM Session"
            $VHD = New-VHD -Path ($oVmHost.VirtualHardDiskPath + "\$Name.vhdx") -SizeBytes $newVHDSizeBytes -Dynamic -CimSession $CimSession -Verbose
            $VM = New-VM @Params -VHDPath ($oVmHost.VirtualHardDiskPath + "\$Name.vhdx") -CimSession $CimSession -Verbose
        }
        Else {
            Write-Host "ComputerName"
            $VHD = New-VHD -Path ($oVmHost.VirtualHardDiskPath + "\$Name.vhdx") -SizeBytes $newVHDSizeBytes -Dynamic -ComputerName $VmHost -Verbose
            $VM = New-VM @Params -VHDPath ($oVmHost.VirtualHardDiskPath + "\$Name.vhdx") -ComputerName $VmHost -Verbose
        }

        # Set additional VM properties
        $VM | Set-VM -ProcessorCount $CPUs -AutomaticStartAction Nothing -AutomaticStopAction Shutdown -DynamicMemory -Verbose
        $VM | Set-VM -SnapshotFileLocation $SnapshotFileLocation -SmartPagingFilePath $SmartPagingFilePath
        $VM | Get-VMDvdDrive | Set-VMDvdDrive -Path $isoPath
        $DVD = ($VM | Get-VMDvdDrive)

        # Set VM boot order based on the VM generation
        Switch ( $Generation ) {
          
            # Generation 1 VM  
            1 {
                $VM | Set-VMBios -StartupOrder @("CD", "IDE", "LegacyNetworkAdapter", "Floppy")
            }
          
            # Generation 2 VM  
            2 {
                $VM | Set-VMFirmware -FirstBootDevice $DVD -EnableSecureBoot On
            }
          
            Default { Write-Host "Opps, shouldn't have gotten here." }
        }   
    }

    END {

        # Get updated VM object and return it
        If ( $CimSession ) {
            $VM = Get-VM -Name $Name -CimSession $CimSession
        }
        Else {
            $VM = Get-VM -Name $Name -ComputerName $Host
        }
        Return $VM
    }
}