<#
    .SYNOPSIS
        Runs Pester tests against a Windows 10 VM to confirm a desired configuration
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
Param()

Write-Host -ForegroundColor Cyan "Checking required module versions."
$Modules = @("Pester", "LatestUpdate")
ForEach ($Module in $Modules) {
    If ([Version]((Find-Module -Name $Module).Version) -gt (Get-Module -Name $Module | Select-Object -Last 1).Version) {
        Write-Host -ForegroundColor Cyan "Installing latest $Module module."
        Install-Module -Name $Module -SkipPublisherCheck -Force
        Import-Module -Name $Module -Force
    }
}

Describe 'Windows 10 1903 validation tests' {
    Context "Validate operating system version" {
        It "Is running Windows Server 2019" {
            (Get-CimInstance -Class Win32_OperatingSystem -Property Caption).Caption | Should -BeLike 'Microsoft Windows 10 Enterprise*'
        }
    }

    Write-Host -ForegroundColor Cyan "Getting Windows feature states."
    $Features = Get-WindowsOptionalFeature -Online

    $NotInstalled = @("SMB1Protocol", "SMB1Protocol-Client", "SMB1Protocol-Server", "Printing-XPSServices-Features", `
            "WindowsMediaPlayer", "Internet-Explorer-Optional-amd64", "WorkFolders-Client", "FaxServicesClientPackage", "TelnetClient")
    $Installed = @("NetFx4-AdvSrvs", "NetFx3")

    Context "Validate Feature configuration" {
        ForEach ($Feature in $NotInstalled) {
            It "Does not have $Feature installed" {
                ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Disabled"
            }
        }
        ForEach ($Feature in $Installed) {
            It "Does have $Feature installed" {
                ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Enabled"
            }
        }
    }

    Write-Host -ForegroundColor Cyan "Getting installed Hotfixes."
    $InstalledUpdates = Get-Hotfix
    Context "Validate installed updates" {
        It "Has the latest Cumulative Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Cumulative Update."
            $Update = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version 1903 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        It "Has the latest Servicing Stack Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Servicing Stack Update."
            $Update = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version 1903 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        Write-Host -ForegroundColor Cyan "Getting latest .NET Framework Update."
        $Updates = Get-LatestNetFrameworkUpdate -OperatingSystem Windows10 | Where-Object { ($_.Architecture -eq "x64") -and ($_.Version -eq "1903") }
        ForEach ($Update in $Updates) {
            It "Has the latest .NET Framework Update installed" {
                $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
            }
        }
        It "Has the latest Adobe Flash Player Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Adobe Flash Player Update."
            $Update = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version 1903 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
    }
}

Write-Host ""
