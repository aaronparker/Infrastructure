<#
    .SYNOPSIS
        Runs Pester tests against a Windows Server VM to confirm a desired configuration
#>
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

Describe 'Windows Server 2019 validation tests' {
    Context "Validate operating system version" {
        It "Is running Windows Server 2019" {
            (Get-CimInstance -Class Win32_OperatingSystem -Property Caption).Caption | Should -BeLike 'Microsoft Windows Server 2019*'
        }
    }

    Write-Host -ForegroundColor Cyan "Getting Windows feature states."
    $Features = Get-WindowsFeature

    $NotInstalled = @("FS-SMB1", "XPS-Viewer")
    $Installed = @("Windows-Defender", "NET-Framework-45-Core", "NET-Framework-45-Features", `
            "NET-Framework-Core", "NET-Framework-Features")

    Context "Validate Feature configuration" {
        ForEach ($Feature in $NotInstalled) {
            It "Does not have $Feature installed" {
                ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $False
            }
        }
        ForEach ($Feature in $Installed) {
            It "Does have $Feature installed" {
                ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $True
            }
        }
    }

    Write-Host -ForegroundColor Cyan "Getting installed Hotfixes."
    $InstalledUpdates = Get-Hotfix
    Context "Validate installed updates" {
        It "Has the latest Cumulative Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Cumulative Update."
            $Update = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        It "Has the latest Servicing Stack Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Servicing Stack Update."
            $Update = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        Write-Host -ForegroundColor Cyan "Getting latest .NET Framework Update."
        $Updates = Get-LatestNetFrameworkUpdate -OperatingSystem Windows10 | Where-Object { ($_.Architecture -eq "x64") -and ($_.Version -eq "1809") } | Select-Object -Last 1
        ForEach ($Update in $Updates) {
            It "Has the latest .NET Framework Update installed" {
                $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
            }
        }
        It "Has the latest Adobe Flash Player Update installed" {
            Write-Host -ForegroundColor Cyan "Getting latest Adobe Flash Player Update."
            $Update = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
    }
}

Write-Host ""
