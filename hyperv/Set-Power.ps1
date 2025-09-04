# Import-Module ActiveDirectory

$cred = Get-Credential Iammred\administrator
$cn = Get-ADComputer -Filter "OperatingSystem -like '* 2012 *'"
$cim = New-CimSession -ComputerName $cn.name -Credential $cred


$cred = Get-Credential home\administrator
$cim = New-CimSession -ComputerName hv1 -Credential $cred
Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "IsActive = 'True'" -CimSession $cim | Format-Table PsComputerName, ElementName

# -------------------

# SetServerPowerSaverPlan.ps1
Import-Module ActiveDirectory

$cred = Get-Credential Iammred\administrator
$cn = Get-ADComputer -Filter "OperatingSystem -like '* 2012 *'"
$cim = New-CimSession -ComputerName $cn.name -Credential $cred

$cred = Get-Credential home\administrator
$cim = New-CimSession -ComputerName hv1 -Credential $cred
$p = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'High performance'" -CimSession $cim
Invoke-CimMethod -InputObject $p[0] -MethodName Activate -CimSession $cim


$p = Get-CimInstance -Name root\cimv2\power -Class win32_PowerPlan -Filter "ElementName = 'Power Saver'" -CimSession $cim
Invoke-CimMethod -InputObject $p[0] -MethodName Activate -CimSession $cim


Get-WmiObject -ComputerName hv1 -Class Win32_PowerPlan -Namespace root\cimv2\power