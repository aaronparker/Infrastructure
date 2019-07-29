<#
    .SYNOPSIS
        Runs Pester tests against a Windows 10 VM to confirm a desired configuration
#>

[CmdletBinding()]
Param(
    [Parameter()] $Version = "1903"
)

Write-Host -ForegroundColor Cyan "`n`tChecking required module versions."
$Modules = @("LatestUpdate", "VcRedist")
ForEach ($Module in $Modules) {
    If ([System.Version]((Find-Module -Name $Module).Version) -gt [System.Version]((Get-Module -Name $Module | Select-Object -Last 1).Version)) {
        Write-Host -ForegroundColor Cyan "`tInstalling latest $Module module."
        Install-Module -Name $Module -SkipPublisherCheck -Force
    }
    Import-Module -Name $Module -Force
}

Describe "Windows 10 version validation tests" {
    Context "Validate operating system version" {
        It "Should be running Windows 10 Enterprise" {
            (Get-CimInstance -Class Win32_OperatingSystem -Property Caption).Caption | Should -BeLike "Microsoft Windows 10 Enterprise*"
        }
        It "Should be running Windows 10 $Version" {
            ([System.Environment]::OSVersion.Version).Build | Should -Be "18362"
        }
    }
}

Describe "Windows 10 feature validation tests" {
    Write-Host -ForegroundColor Cyan "`n`tGetting Windows feature states."
    $Features = Get-WindowsOptionalFeature -Online
    $NotInstalled = @("SMB1Protocol", "SMB1Protocol-Client", "SMB1Protocol-Server", "Printing-XPSServices-Features", `
            "WindowsMediaPlayer", "Internet-Explorer-Optional-amd64", "WorkFolders-Client", "FaxServicesClientPackage", "TelnetClient")

    Context "Validate removed or disabled features" {
        ForEach ($Feature in $NotInstalled) {
            It "Should not have $Feature installed" {
                ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Disabled"
            }
        }
    }
    Context "Validate installed features" {
        $Installed = @("NetFx4-AdvSrvs", "NetFx3")
        ForEach ($Feature in $Installed) {
            It "Should have $Feature installed" {
                ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Enabled"
            }
        }
    }
}

Describe -Tag 'Updates' "Windows 10 update validation tests" {
    Context "Validate Cumulative updates" {
        Write-Host -ForegroundColor Cyan "`n`tGetting installed Hotfixes."
        $InstalledUpdates = Get-Hotfix
        It "Should have the latest Cumulative Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Cumulative Update."
            $LatestUpdate = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }

    Context "Validate Servicing Stack updates" {
        It "Should have the latest Servicing Stack Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Servicing Stack Update."
            $LatestUpdate = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }

    Context "Validate .NET Framework updates" {
        Write-Host -ForegroundColor Cyan "`n`tGetting latest .NET Framework Update."
        $Updates = Get-LatestNetFrameworkUpdate -OperatingSystem Windows10 | Where-Object { ($_.Architecture -eq "x64") -and ($_.Version -eq "$Version") }
        ForEach ($Update in $Updates) {
            It "Should have the latest .NET Framework Update installed" {
                $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
            }
        }
    }

    Context "Validate Adobe Flash updates" {
        It "Should have the latest Adobe Flash Player Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Adobe Flash Player Update."
            $LatestUpdate = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq "x64" } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }
}

Describe "Windows 10 regional settings validation tests" {
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
    }

    Context "Validate time zone settings" {
        It "Should be set to the correct time zone" {
            (Get-TimeZone).Id | Should -Be "AUS Eastern Standard Time"
        }
        It "Should have daylight savings supported" {
            (Get-TimeZone).SupportsDaylightSavingTime | Should -Be $True
        }
    }
}

Describe "Windows 10 software validation tests" {
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
