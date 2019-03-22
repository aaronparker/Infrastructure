#---------------------------------------------------------------------------
# Author: Aaron Parker
# Desc:   Remove a VM from vSphere
# Date:   Mar 24, 2013
# Site:   http://blog.stealthpuppy.com
#---------------------------------------------------------------------------
 
Function Delete-vSphereVM {
    <#
        .SYNOPSIS
            Removes a virtual machine completely
  
        .DESCRIPTION
            Removes a virtula machine completely
  
        .PARAMETER Name
            Specifies the VM to delete.
  
        .EXAMPLE
            PS C:\> Delete-vSphereVM -Name "W7VM1"
 
            Deletes the virtual machine named W7VM1.

        .EXAMPLE
            PS C:\> $VM | Delete-vSphereVM
 
            Deletes the virtual machine piped to this function.
   
        .NOTES
            See http://blog.stealthpuppy.com/ for support information.
  
        .LINK

 
     #>
  
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param(
        [Parameter(Mandatory=$False, ValueFromPipeline=$True, HelpMessage="Specify the VM to retrive the UUID from.")]
        [System.Object]$VM,

        [Parameter(Mandatory=$False, ValueFromPipeline=$False, HelpMessage="Specify the VM name to delete.")]
        [System.Object]$Name
        )
 
    BEGIN {
    }
    
    PROCESS {

        # Remove any existing VM
        # $targetVM = Get-VM | Where-Object { $_.Name -eq $templateVM_Name }
        If ( $VM.PowerState -eq "PoweredOn" ) { Stop-VM -VM $VM -Confirm:$False }
        Do {
            $targetVM = Get-VM | Where-Object { $_.name -eq $vm.Name }
            Switch ($TargetVM.PowerState) {
                {$_ -eq "PoweredOff"}{$Seconds = 0; break}
                {$_ -eq "PoweredOn"}{$Seconds = 10; break}
            }
            Start-Sleep $Seconds
        } Until ( $targetVM.PowerState -eq "PoweredOff" )
        Remove-VM -VM $targetVM -DeletePermanently -Confirm:$False
    }
 
    END {
        # Return the UUID
        # Return $UUIDfixed
    }
}