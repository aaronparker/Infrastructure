#---------------------------------------------------------------------------
# Author: Aaron Parker
# Desc:   Function that uses retrieves the UUID from a specified VM and
#         transposes it into the right format for use with MDT/SCCM etc
# Date:   Mar 24, 2013
# Site:   http://blog.stealthpuppy.com
#
# Original code snippets from: 
# http://communities.vmware.com/thread/239735
# http://www.keithsmithonline.com/2013/02/powershell-show-vmware-vm-UUID.html
#---------------------------------------------------------------------------
 
Function Get-vSphereVMUUID {
    <#
        .SYNOPSIS
            Retrieves the UUID from a specified VM and formats it correctly for use with MDT/SCCM etc.
  
        .DESCRIPTION
            Retrieves the UUID from a specified VM and formats it correctly for use with MDT/SCCM etc. Returns the UUID as a string that can be passed to other functions.
            
            Requires that a VM object is passed to the function. That object will first have to be created before being passed to this function.
  
        .PARAMETER VM
            Specifies the VM to retrieve the UUID from.
  
        .EXAMPLE
            PS C:\> Get-vSphereVMUUID -VM "W7VM1"
 
            Retrieves the UUID from a VM named W7VM1.

        .EXAMPLE
            PS C:\> $VM | Get-vSphereVMUUID
 
            Retrieves the UUID from a VM piped to this function.
   
        .NOTES
            See http://blog.stealthpuppy.com/ for support information.
  
        .LINK
 http://blog.stealthpuppy.com/code/retrieving-a-vms-uuid-from-vsphere/
 
     #>
  
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipeline=$True, HelpMessage="Specify the VM to retrive the UUID from.")]
        [System.Object]$VM
        )
 
    BEGIN {
    }
    
    PROCESS {
        # Retrive UUID from vSphere
        $UUID = $VM | %{(Get-View $_.Id).config.UUID}

        #Transpose UUID into expected format
        # Section 1
        $UUID11 = $UUID.Substring(0,2)
        $UUID12 = $UUID.Substring(2,2)
        $UUID13 = $UUID.Substring(4,2)
        $UUID14 = $UUID.Substring(6,2)

        # Section 2
        $UUID21 = $UUID.Substring(9,2)
        $UUID22 = $UUID.Substring(11,2)

        # Section 3 
        $UUID31 = $UUID.Substring(14,2)
        $UUID32 = $UUID.Substring(16,2)

        # Section 4
        $UUID41 = $UUID.Substring(19,4)

        # Section 5
        $UUID51 = $UUID.Substring(24,12)

        # Piece the strings together
        [string]$UUIDa = "$UUID14$UUID13$UUID12$UUID11"
        [string]$UUIDb = "$UUID22$UUID21"
        [string]$UUIDc = "$UUID32$UUID31"
        [string]$UUIDd = "$UUID41"
        [string]$UUIDe = "$UUID51"
        [string]$UUIDfixed = "$UUIDa-$UUIDb-$UUIDc-$UUIDd-$UUIDe"
    }
 
    END {
        # Return the UUID
        Return $UUIDfixed
    }
}