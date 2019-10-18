# Variables
$StoragePoolName = "StoragePool"
$TieredSpaceName = "TieredSpace"
$ResiliencySetting = "Simple"
$SSDTierName = "SSDTier"
$HDDTierName = "HDDTier"

# Drives to be included in the storage pool
$Drives = @(3, 4)

# Reset drives
ForEach ($Drive in $Drives) {
    Get-PhysicalDisk -DeviceNumber $Drive | Reset-PhysicalDisk
}

# Ensure enough poolable drives exist after reset
If ((Get-PhysicalDisk -CanPool $True).Count -lt 2) { Write-Error -Message "Failed to find enough poolable drives." }

# Set unspecified drives to HDD
Get-PhysicalDisk -CanPool $True | Where-Object { $_.MediaType -eq "Unspecified" } | `
    Set-PhysicalDisk -MediaType HDD

# Store all physical disks that can be pooled into a variable, $PoolableDisks
# $PoolableDisks = (Get-PhysicalDisk -CanPool $True | Where-Object { $_.MediaType -ne "Unspecified" })
$PoolableDisks = Get-PhysicalDisk | Where-Object { ($_.DeviceId -eq 3) -or ($_.DeviceId -eq 4) }

# Create a new Storage Pool using the disks in variable $PoolableDisks
$SubSysName = (Get-StorageSubSystem).FriendlyName
New-StoragePool -PhysicalDisks $PoolableDisks -StorageSubSystemFriendlyName $SubSysName -FriendlyName $StoragePoolName `
    -AutoWriteCacheSize $True -ResiliencySettingNameDefault $ResiliencySetting

# View the disks in the Storage Pool just created
Get-StoragePool -FriendlyName $StoragePoolName | Get-PhysicalDisk | `
    Select-Object -Property FriendlyName, MediaType | Format-List

# Upgrade the storage pool
Get-StoragePool -IsPrimordial $False | Update-StoragePool -Confirm:$False

# Create two tiers in the Storage Pool created. One for SSD disks and one for HDD disks
$SSDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $SSDTierName -MediaType SSD `
    -ResiliencySettingName $ResiliencySetting
$HDDTier = New-StorageTier -StoragePoolFriendlyName $StoragePoolName -FriendlyName $HDDTierName -MediaType HDD `
    -ResiliencySettingName $ResiliencySetting

# Identify tier sizes within this storage pool
$SSDTierSize = ((Get-StorageTierSupportedSize -FriendlyName $SSDTierName).TierSizeMax) / 1GB
$HDDTierSize = ((Get-StorageTierSupportedSize -FriendlyName $HDDTierName).TierSizeMax) / 1GB

# Create a new virtual disk in the pool with a name of TieredSpace using the SSD and HDD tiers
New-VirtualDisk -StoragePoolFriendlyName $StoragePoolName -FriendlyName $TieredSpaceName -StorageTiers $SSDTier, $HDDTier `
    -StorageTierSizes 230GB, 930GB -ResiliencySettingName $ResiliencySetting


# ---
Get-StoragePool -IsPrimordial $False | Remove-StoragePool -Confirm:$False
