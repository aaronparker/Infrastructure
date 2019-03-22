Function Delete-VM {
    <#
        .SYNOPSIS
            Removes a virtual machine on a Hyper-V host and deletes the associated virtual hard disks.
 
        .DESCRIPTION
            Removes a virtual machine on a Hyper-V host and deletes the associated virtual hard disks.
            
        .PARAMETER ComputerName
            The hostname of the Hyper-V host where the virtual machine exists.
            Defaults to the local host if not specified.

        .PARAMETER VM
            The virtual machine to delete. Multiple virtual machines can be specified.
            
        .PARAMETER Username
			The username used to connect to a remove Hyper-V server.
        
        .PARAMETER Password
			The password for the username specified.
        
        .PARAMETER CimSession
			A CIM session to a remote host that can be passed to this function for authenticating against a remote host.
  
        .EXAMPLE
            PS C:\> Delete-VM -ComputerName hyperv1 -VM sql1, web1
            
            Rmoves the virtual machines sql1 and web1 from the host hyperv1 and deletes their associated virtual hard disks.
            
        .NOTES
 	        NAME: Delete-VM.ps1
	        VERSION: 1.0
	        AUTHOR: Aaron Parker
	        LASTEDIT: April 16, 2016
 
        .LINK
            http://stealthpuppy.com
    #>
    [CmdletBinding(SupportsShouldProcess = $False, ConfirmImpact = "High", DefaultParameterSetName = "Auth")]
    PARAM (
        [Parameter(Mandatory=$True, HelpMessage="Specify a virtual machine to delete.")]
        [string[]]$VM,
        
        [Parameter(ParameterSetName="Auth", Mandatory=$False, HelpMessage="Specify a host where the target virtual machine exists.")]
        [string]$ComputerName = $env:COMPUTERNAME,

        [Parameter(ParameterSetName="Auth", Mandatory=$False, HelpMessage="Specify a username used to connect to a remote Hyper-V host.")]
        [string]$Username,
        
        [Parameter(ParameterSetName="Auth", Mandatory=$False, HelpMessage="Specify a password for authentication with the specified username.")]
        [string]$Password,
        
        [Parameter(ParameterSetName="Cim", Mandatory=$False)]
        [Microsoft.Management.Infrastructure.CimSession]$CimSession        
    )
    
    BEGIN {
        
        # If username/password passed to function, create a CIM session to authenticate to remote host
        If ($PSBoundParameters['Username']) {
                If ($PSBoundParameters['Password']) {
                    
                    # Convert a string to a secure string and create a credential object
                    $SecurePassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
                    $cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $Username, $SecurePassword
                    
                    # Try a connection to the remote host before creating the CIM session
                    Try {
                        Test-Connection -ComputerName $ComputerName -Count 1 -ErrorVariable TestError -ErrorAction Stop
                    }
                    Catch {
                        Write-Error "Failed to connect with error: " $TestError
                        Return
                    }
                    
                    Try {
                        $cim = New-CimSession -Credential $cred -ComputerName $ComputerName -ErrorVariable CimError -ErrorAction Stop    
                    }
                    Catch {
                        Write-Error "Failed to to create CIM session with: " $CimError
                        Return
                    }
                    
                }
        }

        # If a CIM session passed just use that. (no need to pass one CIM session into another, though)
        If ($PSBoundParameters['CimSession']) {
            $cim = $CimSession
        }
    }
        
    PROCESS {
        
        # Walk through each VM and remove it along with its virtual hard disks
        # Need to fix Invoke-Command 
        ForEach ( $v in $VM ) {
            $machine = Get-VM -CimSession $cim -Name $v -ErrorVariable Error -ErrorAction SilentlyContinue
            $VHDs = $machine | Get-VMHardDiskDrive
            Invoke-Command -ComputerName $ComputerName -Credential $cred -ScriptBlock { param($VHDs) ForEach ( $vhd in $VHDs) { Remove-Item -Path $vhd.Path -Force -Confirm:$False -Verbose } } -Args $VHDs
			$machine | Remove-VM -Force -Verbose
        }
    }
}