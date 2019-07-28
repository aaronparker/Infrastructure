<#
    .SYNOPSIS
        Runs Pester tests against a Windows Server 2019 VM to confirm a desired configuration
#>
#Requires -RunAsAdministrator
#Requires -PSEdition Desktop
[CmdletBinding()]
Param(
    [Parameter()] $Version = "1809"
)

Write-Host -ForegroundColor Cyan "`n`tChecking required module versions."
$Modules = @("Pester", "LatestUpdate", "VcRedist")
ForEach ($Module in $Modules) {
    If ([Version]((Find-Module -Name $Module).Version) -gt [Version]((Get-Module -Name $Module | Select-Object -Last 1).Version)) {
        Write-Host -ForegroundColor Cyan "`tInstalling latest $Module module."
        Install-Module -Name $Module -SkipPublisherCheck -Force
    }
    Import-Module -Name $Module -Force
}

Describe 'Windows Server 2019 validation tests' {
    Context "Validate operating system version" {
        It "Is running Windows Server 2019" {
            (Get-CimInstance -Class Win32_OperatingSystem -Property Caption).Caption | Should -BeLike 'Microsoft Windows Server 2019*'
        }
        It "Should be running Windows 10 $Version" {
            ([System.Environment]::OSVersion.Version).Build | Should -Be "17763"
        }
    }

    Context "Validate Feature configuration" {
        Write-Host -ForegroundColor Cyan "`nGetting Windows feature states."
        $Features = Get-WindowsFeature
        $NotInstalled = @("FS-SMB1", "XPS-Viewer")
        ForEach ($Feature in $NotInstalled) {
            It "Does not have $Feature installed" {
                ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $False
            }
        }
        $Installed = @("Windows-Defender", "NET-Framework-45-Core", "NET-Framework-45-Features", `
                "NET-Framework-Core", "NET-Framework-Features")
        ForEach ($Feature in $Installed) {
            It "Does have $Feature installed" {
                ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $True
            }
        }
    }

    Context "Validate installed updates" {
        Write-Host -ForegroundColor Cyan "`nGetting installed Hotfixes."
        $InstalledUpdates = Get-Hotfix
        It "Has the latest Cumulative Update installed" {
            Write-Host -ForegroundColor Cyan "`nGetting latest Cumulative Update."
            $Update = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        It "Has the latest Servicing Stack Update installed" {
            Write-Host -ForegroundColor Cyan "`nGetting latest Servicing Stack Update."
            $Update = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
        Write-Host -ForegroundColor Cyan "`nGetting latest .NET Framework Update."
        $Updates = Get-LatestNetFrameworkUpdate -OperatingSystem Windows10 | Where-Object { ($_.Architecture -eq "x64") -and ($_.Version -eq "1809") }
        ForEach ($Update in $Updates) {
            It "Has the latest .NET Framework Update installed" {
                $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
            }
        }
        It "Has the latest Adobe Flash Player Update installed" {
            Write-Host -ForegroundColor Cyan "`nGetting latest Adobe Flash Player Update."
            $Update = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version 1809 | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
        }
    }

    Context "Validate language and regional settings" {
        It "Should have Regional settings set to en-AU" {
            (Get-Culture).Name | Should -Be "en-AU"
        }
        It "Should have the correct Windows display language" {
            (Get-UICulture).Name | Should -BeIn @("en-US", "en-AU", "en-GB")
        }
        It "Should have System locale set to en-AU" {
            (Get-WinSystemLocale).Name | Should -Be "en-AU"
        }
        It "Should be set to the correct time zone" {
            (Get-TimeZone).Id | Should -Be "AUS Eastern Standard Time"
        }
        It "Should have daylight savings supported" {
            (Get-TimeZone).SupportsDaylightSavingTime | Should -Be $True
        }
    }

    Context "Validate installed software" {
        Write-Host -ForegroundColor Cyan "`n`tGetting installed Visual C++ Redistributables."
        $InstalledVcRedists = Get-InstalledVcRedist
        ForEach ($VcRedist in (Get-VcList -Release "2010", "2012", "2013", "2019")) {
            It "Should have Visual C++ Redistributable $($VcRedist.Release) $($VcRedist.Architecture) $($VcRedist.Version) installed" {
                $Match = $InstalledVcRedists | Where-Object { ($_.Release -eq $VcRedist.Release) -and ($_.Architecture -eq $VcRedist.Architecture) }
                $Match.ProductCode | Should -Match $VcRedist.ProductCode
            }
        }
    }

}

Write-Host ""
