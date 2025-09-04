Function Get-HvMem {
    <#
        .SYNOPSIS
            Return Hyper-V host RAM details.
 
        .DESCRIPTION
            This function returns the total available RAM, RAM in use by VMs and the available RAM on a Hyper-V host.
 
        .PARAMETER ComputerName
            Specifies one or more Hyper-V hosts to retrieve stats from.
 
        .EXAMPLE
            Get-HvRAM -ComputerName hyperv1

        .NOTES
 
        .LINK
            http://stealthpuppy.com/hyperv-memory-powershell
 
    #>
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Hyper-V host.")]
        [string[]]$ComputerName = $(throw = "Please specify a remote Hyper-V host to gather memory details from.")
    )

    # Create an array to return
    $allStats = @()

    ForEach ( $computer in $ComputerName ) {

        # Create an array to contain this computer's metrics
        $a = @()

        # Get details for Hyper-V host
        $vmHost = Get-VMHost -ComputerName $computer

        If ($vmHost) {

            # Get total RAM consumed by running VMs.
            $total = 0
            Get-VM -ComputerName hv1 | Where-Object { $_.State -eq "Running" } | Select-Object Name, MemoryAssigned | ForEach-Object { $total = $total + $_.MemoryAssigned }

            #Get available RAM via performance counters
            $Bytes = Get-Counter -ComputerName $computer -Counter "\Memory\Available Bytes"

            # Convert values to GB
            $availGB = ($Bytes[0].CounterSamples.CookedValue / 1GB)
            $hostGB = ($vmhost.MemoryCapacity / 1GB)
            $vmInUse = ($total / 1GB)

            # Construct an array of properties to return
            $item = New-Object PSObject

            # Add host name
            $item | Add-Member -type NoteProperty -Name 'Name' -Value $vmHost.Name

            # Host RAM in GB
            $item | Add-Member -type NoteProperty -Name 'HostRAMGB' -Value $hostGB

            # In use RAM in GB
            $item | Add-Member -type NoteProperty -Name 'VMInUseGB' -Value $vmInUse

            # System used in GB
            $item | Add-Member -type NoteProperty -Name 'SystemUsedGB' -Value ($hostGB - ($vmInUse + $availGB))

            # Available RAM in GB
            $item | Add-Member -type NoteProperty -Name 'AvailableGB' -Value $availGB
            $a += $item    
        }

        # Add the current machine details to the array to return
        $allStats += $a
    }
    Return $allStats
}
