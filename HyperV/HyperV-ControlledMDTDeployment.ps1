#---------------------------------------------------------------------------
# Controlled MDT deployment
#---------------------------------------------------------------------------

# Set variables (change these to arguments later)
$MDTBootISO = "D:\TechDays\Boot\Test_LiteTouchPE_x86.iso"
# $MDTBootISO = "D:\Deployment\Boot\KelwayLiteTouchPE_x86.iso"
$TargetVM_OSName = "WIN81"
$TaskSequenceID = "W8_ENT_X64"
$MachineObjectOU = "OU=Desktops,DC=lab,DC=com"
$TargetVM_Name = "WIN81"
$VMTemplate = "VMTemplate"
$DeploymentShare = "D:\TechDays"
$CustomSettingsINI = "$DeploymentShare\Control\CustomSettings.ini"
$VMHostName = "HYPERV1"
$SwitchName = "Internal"
$Seconds = 5

# Get Hyper-V host properties
Write-Verbose "Getting host properties." -ForegroundColor Green
$VMHost = Get-VMHost -ComputerName $VMHostName

# Remove any existing VM
[string]$vDiskPath = "path"
$TargetVM = Get-VM | Where-Object { $_.Name -eq $TargetVM_Name }
If ( $TargetVM -ne $Null ) {
    Write-Verbose "Found existing VM." -ForegroundColor Green
    $VMHardDisk = $TargetVM | Get-VMHardDiskDrive
    $vDiskPath = $VMHardDisk.Path
    If ( $TargetVM.State -eq "Running" ) { Write-Verbose "Stopping VM..." -ForegroundColor Green ; Stop-VM -VM $TargetVM -Force -Confirm:$False }
    Do {
        $TargetVM = Get-VM | Where-Object { $_.name -eq $TargetVM_Name }
        Switch ($TargetVM.State) {
                {$_ -eq "Off"}{$Seconds = 0; break}
                {$_ -eq "Running"}{$Seconds = 10; break}
        }
        Start-Sleep $Seconds
    } Until ( $TargetVM.State -eq "Off" )
    Write-Verbose "Removing VM." -ForegroundColor Green
    Remove-VM -VM $TargetVM -Force -Confirm:$False -Verbose
    If (Test-Path $vDiskPath) { Remove-Item $vDiskPath -Force -Confirm:$False -Verbose }
}

# Create a VM
Write-Verbose "Creating new VM $TargetVM_Name." -ForegroundColor Green
$VHDPath = $VMHost.VirtualHardDiskPath
New-VM –Name $TargetVM_Name -SwitchName $SwitchName –MemoryStartupBytes 1024MB -NewVHDSizeBytes 64GB -NewVHDPath "$VHDPath$TargetVM_Name.vhdx" -BootDevice CD -Verbose
Get-VMDvdDrive -VMName $TargetVM_Name | Set-VMDvdDrive -Path $MDTBootISO -Verbose
Set-VM -Name $TargetVM_Name -ProcessorCount 2 -AutomaticStartAction Nothing -AutomaticStopAction Shutdown -DynamicMemory -Verbose

# Get the target VM's UUID
Write-Verbose "Retrieving target VM's UUID." -ForegroundColor Green
$UUIDs = Get-VM -ComputerName $VMHostName | Select-Object Name,VMId,@{Name="BIOSGUID";Expression={(Get-WmiObject -ComputerName $_.ComputerName -Namespace "root\virtualization" -Class Msvm_VirtualSystemSettingData -Property BIOSGUID -Filter ("InstanceID = 'Microsoft:{0}'" -f $_.VMId.Guid)).BIOSGUID}}
$UUID = $UUIDs | Where-Object { $_.Name -eq $TargetVM_Name } | Select BIOSGUID
$TargetVMUUID = $UUID.BIOSGUID -Replace "{", ""
$TargetVMUUID = $TargetVMUUID -Replace "}", ""


# Connect to the MDT share
Write-Verbose "Connecting to MDT." -ForegroundColor Green
Add-PSSnapin 'Microsoft.BDD.PSSNAPIN' -ErrorAction SilentlyContinue
# If ((Get-Module 'Microsoft.BDD.PSSNAPIN') -eq $null) { throw "Module did not load" }
If (!(Test-Path MDT:)) { New-PSDrive -Name MDT -Root $DeploymentShare -PSProvider MDTPROVIDER }

# Write settings for the target VM to MDT CustomSettings.ini
# open INI file, create or edit section, assign task sequence, configure deployment wizard
Write-Verbose "Backing up CustomSettings.ini." -ForegroundColor Green
If (!(Test-Path "$DeploymentShare\Control\CustomSettings-Backup.ini")) { Copy-Item $CustomSettingsINI "$DeploymentShare\Control\CustomSettings-Backup.ini" -Force }

# Create new content for the INI file and write back to the file
Write-Verbose "Adding control section for $TargetVM_Name." -ForegroundColor Green
$Category1 = @{"OSDComputerName"=$TargetVM_OSName;"TaskSequenceID"=$TaskSequenceID;"MachineObjectOU"=$MachineObjectOU;"WindowsUpdate"="FALSE";"SkipSummary"="YES";"SkipTaskSequence"="YES";"SkipApplications"="YES";"SkipLocaleSelection"="YES";"SkipDomainMembership"="YES";"SkipTimeZone"="YES";"SkipComputerName"="YES";"SkipUserData"="YES";"SkipComputerBackup"="YES"}
$NewINIContent = @{$TargetVMUUID=$Category1}
Write-Verbose "Writing to CustomSettings.ini." -ForegroundColor Green
Out-IniFile -InputObject $NewINIContent -FilePath $CustomSettingsINI -Force ASCII -Append

# Clean up the MDT monitor data for the target VM if it exists
Write-Verbose "Clearing MDT monitor data." -ForegroundColor Green
Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $TargetVM_OSName } | Remove-MDTMonitorData -Path MDT:

# Start the VM
Write-Verbose "Starting $TargetVM_Name..." -ForegroundColor Green
$TargetVM = Get-VM | Where-Object { $_.Name -eq $TargetVM_Name }
If (!($TargetVM.State -eq "On")) { $TargetVM | Start-VM -Verbose }

# Wait for the OS deployment to start before monitoring
# This may require user intervention to boot the VM from the MDT ISO if an OS exists on the vDisk
If ((Test-Path variable:InProgress) -eq $True) { Remove-Variable -Name InProgress }
Do {
    $InProgress = Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $TargetVM_OSName -and $_.DeploymentStatus -eq 1 }
    If ($InProgress) {
        If ($InProgress.PercentComplete -eq 100) {
            $Seconds = 30
            $TSStarted = $False
            Write-Verbose "Waiting for task sequence to begin..." -ForegroundColor Green
        } Else {
            $Seconds = 0
            $TSStarted = $True
            Write-Verbose "Task sequence has begun. Moving to monitoring phase." -ForegroundColor Green
        }
    } Else {
        $Seconds = 30
        $TSStarted = $False
        Write-Verbose "Waiting for task sequence to begin..." -ForegroundColor Green
    }
    Start-Sleep -Seconds $Seconds
} Until ($TSStarted -eq $True)

# Connect to VM console
Write-Verbose "Opening console to $TargetVM_Name." -ForegroundColor Green
vmconnect $VMHostName $TargetVM.VMName
 
# Monitor the MDT OS deployment once started
Write-Verbose "Monitoring task sequence." -ForegroundColor Green
Do {
    $InProgress = Get-MDTMonitorData -Path MDT: | Where-Object { $_.Name -eq $TargetVM_OSName }
    If ( $InProgress.PercentComplete -lt 100 ) {
        If ( $InProgress.StepName.Length -eq 0 ) { $StatusText = "Waiting for update" } Else { $StatusText = $InProgress.StepName }
        Write-Progress -Activity "Task sequence in progress" -Status $StatusText -PercentComplete $InProgress.PercentComplete
        Switch ($InProgress.PercentComplete) {
            {$_ -lt 25}{$Seconds = 35; break}
            {$_ -lt 50}{$Seconds = 30; break}
            {$_ -lt 75}{$Seconds = 10; break}
            {$_ -lt 100}{$Seconds = 0; break}
        }
        Start-Sleep -Seconds $Seconds
    }
} Until ($InProgress.CurrentStep -eq $InProgress.TotalSteps)
Write-Verbose "Task sequence complete." -ForegroundColor Green
Start-Sleep -Seconds 8

# Shutdown the target VM
# Write-Verbose "Shutting down $TargetVM_Name." -ForegroundColor Green
# $TargetVM = Get-VM | Where-Object { $_.Name -eq $TargetVM_Name }
# If ( $TargetVM -ne $Null ) {
#     If ( $TargetVM.State -eq "Running" ) { Stop-VM -VM $TargetVM -Force }
#     Do {
#        $TargetVM = Get-VM | Where-Object { $_.name -eq $TargetVM_Name }
#         Switch ($TargetVM.State) {
#                 {$_ -eq "Off"}{$Seconds = 0; break}
#                 {$_ -eq "Running"}{$Seconds = 10; break}
#         }
#         Start-Sleep $Seconds
#     } Until ( $TargetVM.State -eq "Off" )
# }

Write-Verbose "Script complete." -ForegroundColor Green