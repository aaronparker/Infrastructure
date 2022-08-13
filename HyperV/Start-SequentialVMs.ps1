Function Start-SequentialVMs {
    <#
        .SYNOPSIS
            Starts a list of VMs.
 
        .DESCRIPTION
            This function starts a list of VMs sequentially. It will wait until a VM is booted, optionally pause for a number of seconds, before starting the next VM.
 
        .PARAMETER ComputerName
            Specifies the Hyper-V host to start the VM on.
 
        .PARAMETER VM
            Specifies a list of VMs to start.
 
        .PARAMETER Wait
            Specifies a number of seconds to wait after the previous VM has booted successfully. Defaults to 180 seconds.

        .PARAMETER ShowProgress
            Specified whether to show progress as VMs are started.
 
        .EXAMPLE
            Start-SequentialVMs -ComputerName hyperv1 -VMList "sql1", "pvs1", "xd71" -Wait 20

        .NOTES
 
        .LINK
            http://stealthpuppy.com/sequential-start-vms
 
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Hyper-V host.")]
        [string]$ComputerName = $(throw = "Please specify a remote Hyper-V host to start VMs on."),

        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "List of VMs to start.")]
        [string[]]$VMList = $(throw = "Please specifiy a list of VMs to start"),

        [Parameter(Mandatory = $false)]
        [int]$Wait = 180,

        [Parameter(Mandatory = $false)]
        [bool]$ShowProgress
    )

    # Connect to Hyper-V host before attempting to start VMs. Stop script if unable to connect
    Write-Verbose "Connecting to VM host."
    Get-VMHost -ComputerName $ComputerName -Verbose $False -ErrorAction Stop

    # Start progress at 0
    $Percent = 0

    # Step through list of provided VMs
    ForEach ( $vm in $VMList ) {

        # Convert current location in list of VMs to a percentage
        $Percent = ($VMList.IndexOf($vm) / $VMList.Count) * 100

        # Show progress if specified on the command line
        If ($ShowProgress -eq $True) { Write-Progress -Activity "Starting VMs." -Status "Starting VM $vm." -PercentComplete $Percent }

        # Get status for current VM
        Remove-Variable currentVM -ErrorAction SilentlyContinue
        Write-Verbose "Getting status for VM $vm..."
        $currentVM = Get-VM -ComputerName $ComputerName -Name $vm -ErrorAction SilentlyContinue

        # If the VM exists, then power it on if it is in an Off state
        If ($currentVM.Length -gt 0) {
            If ($currentVM.State -eq "Off" ) {
                Start-VM -ComputerName $ComputerName -Name $vm -Verbose
                
                # Wait for VM to boot and report a heartbeat
                Write-Verbose "Waiting for VM heartbeat."
                Do {
                    Start-Sleep -Milliseconds 100
                } Until ((Get-VMIntegrationService $currentVM | ? { $_.name -eq "Heartbeat" }).PrimaryStatusDescription -eq "OK")

                # Wait the specified number of seconds before booting the next VM, unless this is the last VM in the list
                If ($Wait -gt 0 -and $VMList.IndexOf($vm) -lt ($VMList.Count - 1)) {
                    Write-Verbose "Waiting for $Wait seconds before starting next VM."
                    Start-Sleep -Seconds $Wait
                }

            }
            Else {
                Write-Verbose "VM $vm already running."
            }

        }
        Else {
            Write-Error -Message "Unable to find VM $vm on host $ComputerName." -Category ObjectNotFound
        }

    }

    Write-Verbose "Started VMs."

    # Show progress if specified on the command line
    If ($ShowProgress -eq $True) { Write-Progress -Activity "Starting VMs." -Status "Started all VMs." -PercentComplete 100 }
    Start-Sleep -Seconds 1
}