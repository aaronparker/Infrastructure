# Find used space on the C: drive
$Drive = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $env:SystemDrive }
$UsedSpace = ($Drive.Size - $Drive.FreeSpace)/1GB
Write-Host $UsedSpace

# Run all EXE files in subfolders one-by-one
Get-ChildItem -Recurse -File -Include *.exe | Select FullName | ForEach { Start-Process -FilePath $_.FullName -Wait }

# Enable .NET Framework 3.5 on Windows 8/10
Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -Source "\\mcfly\Deployment\Reference\Operating Systems\Windows 10 Enterprise x64\sources\sxs"
