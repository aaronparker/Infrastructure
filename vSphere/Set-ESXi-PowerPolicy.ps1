$esxiHost = "hv2.home.stealthpuppy.com"
$vCenterHost = "vcenter.home.stealthpuppy.com"

Add-PSSnapin "vmware.VimAutomation.core" -ErrorAction SilentlyContinue
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Scope Session -Confirm:$False -DisplayDeprecationWarnings:$False

Connect-VIServer -Server $esxiHost -User root -Password Passw0rd

Get-VMHost | Sort | Select Name,
@{ N="CurrentPolicy"; E={$_.ExtensionData.config.PowerSystemInfo.CurrentPolicy.ShortName}},
@{ N="CurrentPolicyKey"; E={$_.ExtensionData.config.PowerSystemInfo.CurrentPolicy.Key}},
@{ N="AvailablePolicies"; E={$_.ExtensionData.config.PowerSystemCapability.AvailablePolicy.ShortName}}

$view = (Get-VMHost $esxiHost | Get-View)
(Get-View $view.ConfigManager.PowerSystem).ConfigurePowerPolicy(2)



Function Set-VMHostPowerPolicy{
    <#
        .SYNOPSIS
            remove items from folders recursively.
 
        .DESCRIPTION
            this function removes items older than a specified age from the target folder
 
        .PARAMETER Days
            Specifies the ammount of days since the file was last written to you wish to filter on.
 
        .PARAMETER Path
            Specifies the path to the folder you wish to search recursively.
 
        .PARAMETER Silent
            Instructs the function not to return any output.
 
         .EXAMPLE
            PS C:\> remove-itembyage -days 0 -path $recent
 
            This command searches the $recent directory, for any files, then deletes them.
 
        .EXAMPLE
            PS C:\> remove-itembyage -days 5 -path $recent
 
            This command searches the $recent directory, for files older than 5 days, then deletes them.
 
        .EXAMPLE
            PS C:\> remove-itembyage -days 10 -path $appdata -typefilter "txt,log"
 
            This command searches the $cookies directory, for files older than 10 days and end with txt or log extensions, then deletes them.
 
        .EXAMPLE
            PS C:\> remove-itembyage -days 10 -path $cookies -typefilter "txt,log" -silent
 
            This command searches the $cookies directory, for files older than 10 days and end with txt or log extensions, then deletes them without a report.
 
        .NOTES
            http://blog.stealthpuppy.com/user-virtualization/profile-clean-up-script-powershell-edition/ for support information.
 
        .LINK
 
 
    #>
 
    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        [Parameter(Mandatory=$true, Position=0,HelpMessage="Number of days to filter by, E.G. ""14""")]
        [int]$days,
        [Parameter(Mandatory=$true, Position=1,HelpMessage="Path to files you wish to delete")]
        [string]$path,
        [string]$typefilter,
        [switch]$silent)
 
   

    $view = (Get-VMHost $esxiHost | Get-View)
    (Get-View $view.ConfigManager.PowerSystem).ConfigurePowerPolicy(2)

} #end function


Get-AdvancedSetting -Entity (Get-VMHost $esxiHost) -Name 'Power.CPUPolicy' | Set-AdvancedSetting -Value 'Dynamic' -Confirm:$False

Set-AdvancedSetting -AdvancedSetting 

Get-AdvancedSetting -Entity (Get-VMHost $esxiHost) | Select * | ft