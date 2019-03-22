#---------------------------------------------------------------------------
# Author: Aaron Parker
# Desc:   Function that uses retrieves the UUID from a specified VM and
#         formats it into the right format for use with MDT/SCCM etc
# Date:   Aug 18, 2014
# Site:   http://stealthpuppy.com
#---------------------------------------------------------------------------
 

Function Get-HypervVMUUID {

   <#
        .SYNOPSIS
            Retrieve the UUID from a virtual machine or set of virtual machines.
 
        .DESCRIPTION
            This function will retrieve the UUID from from a virtual machine or set of virtual machines from a Hyper-V host.
 
        .PARAMETER ComputerName
            Specifies the host from which to query the virtual machine or set of virtual machines.
 
        .PARAMETER VM
            Specifies the virtual machine or set of virtual machines (a comma delimited list) from which to obtain the UUID/s.
 
         .EXAMPLE
            PS C:\> Get-HypervVMUUID -ComputerName hv1 -VM win71, win72
 
            This command retrieves the UUIDs from the virtual machines win71 and win72 from the host hv1.
 
        .EXAMPLE
            PS C:\> Get-HypervVMUUID -VM win71, win72
 
            This command retrieves the UUIDs from the virtual machines win71 and win72 from the local host.
 
        .EXAMPLE
            PS C:\> Get-HypervVMUUID
 
            This command retrieves the UUIDs from the all of the virtual machines on the local host.
 
        .NOTES
            http://stealthpuppy.com/retrieving-a-vms-uuid-from-hyperv/ for support information.
 
        .LINK
 
http://stealthpuppy.com/retrieving-a-vms-uuid-from-hyperv/
 
    #>

    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        [Parameter(Mandatory=$false,HelpMessage="Specifies one or more Hyper-V hosts from which virtual machine UUIDs are to be retrieved. NetBIOS names, IP addresses, and fully-qualified domain names are allowable. The default is the local computer — use ""localhost"" or a dot (""."") to specify the local computer explicitly.")]
        [string]$ComputerName,

        [Parameter(Mandatory=$false, Position=0,HelpMessage="Specifies the virtual machine from which to retrieve the UUID.")]
        [string[]]$VM
    )

    # If ComputerName parameter is not specified, set value to the local host
    If (!$ComputerName) { $ComputerName = "." }

    # If VM parameter is specified, return those VMs, else return all VMs
    If ($VM) {
        $UUIDs = Get-VM -ComputerName $ComputerName -VM $VM -ErrorAction SilentlyContinue | Select-Object Name,@{Name="BIOSGUID";Expression={(Get-WmiObject -ComputerName $_.ComputerName -Namespace "root\virtualization\v2" -Class Msvm_VirtualSystemSettingData -Property BIOSGUID -Filter ("InstanceID = 'Microsoft:{0}'" -f $_.VMId.Guid)).BIOSGUID}}
    } Else {
        $UUIDs = Get-VM -ComputerName $ComputerName -ErrorAction SilentlyContinue | Select-Object Name,@{Name="BIOSGUID";Expression={(Get-WmiObject -ComputerName $_.ComputerName -Namespace "root\virtualization\v2" -Class Msvm_VirtualSystemSettingData -Property BIOSGUID -Filter ("InstanceID = 'Microsoft:{0}'" -f $_.VMId.Guid)).BIOSGUID}}
    }

    # Remove curly brackets from the UUIDs and return the array
    ForEach ( $UID in $UUIDs ) { $UID.BIOSGUID = $UID.BIOSGUID -replace "}"; $UID.BIOSGUID = $UID.BIOSGUID -replace "{" }
    Return $UUIDs
}