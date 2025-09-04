<#
    .SYNOPSIS
        Runs Pester tests against a Windows 10 VM to confirm a desired configuration
#>
#Requires -RunAsAdministrator
#Requires -PSEdition Desktop
[CmdletBinding()]
Param()

# Environment setup
Write-Host -ForegroundColor Cyan "`n`tGetting operating system version."
$Builds = @{
    "18362" = "1903"
    "17763" = "1809"
    "17134" = "1803"
    "16299" = "1709"
    "15063" = "1703"
    "14393" = "1607"
}
$Version = $Builds.$((([System.Environment]::OSVersion.Version).Build).ToString())
Write-Host -ForegroundColor Cyan "`tGetting Windows edition."
$Edition = Get-WindowsEdition -Online
Write-Host -ForegroundColor Cyan "`tGetting installed Hotfixes."
$InstalledUpdates = Get-Hotfix
Write-Host -ForegroundColor Cyan "`tGetting Windows feature states."
Switch -Regex ($Edition.Edition) {
    "Pro|Enterprise" {
        Write-Host -ForegroundColor Cyan "`tPlatform is Windows 10."
        $Features = Get-WindowsOptionalFeature -Online
        $NotInstalled = @("SMB1Protocol", "SMB1Protocol-Client", "SMB1Protocol-Server", "Printing-XPSServices-Features", `
                "WindowsMediaPlayer", "Internet-Explorer-Optional-amd64", "WorkFolders-Client", "FaxServicesClientPackage", "TelnetClient")
        $Installed = @("NetFx4-AdvSrvs", "NetFx3")
        $VcReleases = @("2010", "2012", "2013", "2019")
    }
    "ServerStandard|ServerDatacenter" {
        Write-Host -ForegroundColor Cyan "`tPlatform is Windows Server."
        $Features = Get-WindowsFeature
        $NotInstalled = @("FS-SMB1", "XPS-Viewer")
        $Installed = @("Windows-Defender", "NET-Framework-45-Core", "NET-Framework-45-Features", `
                "NET-Framework-Core", "NET-Framework-Features")
        $VcReleases = @("2019")
    }
}
Switch ([intptr]::Size) {
    4 { $Proc = "x86" }
    8 { $Proc = "x64" }
}

Describe "Windows version validation tests" {
    Context "Validate operating system" {
        It "Should be running a valid Windows edition" {
            $EditionMatch = $Edition.Edition -match "Enterprise|ServerStandard|ServerDatacenter"
            $EditionMatch | Should -BeTrue
        }
    }
}

Describe "Windows feature validation tests" {
    Context "Validate removed or disabled features" {
        ForEach ($Feature in $NotInstalled) {
            It "Should not have $Feature installed" {
                Switch -Regex ($Edition.Edition) {
                    "Pro|Enterprise" {
                        ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Disabled"
                    }
                    "ServerStandard|ServerDatacenter" {
                        ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $False
                    }
                }
            }
        }
    }
    Context "Validate installed features" {
        ForEach ($Feature in $Installed) {
            It "Should have $Feature installed" {
                Switch -Regex ($Edition.Edition) {
                    "Pro|Enterprise" {
                        ($Features | Where-Object { $_.FeatureName -eq $Feature }).State | Should -Be "Enabled"
                    }
                    "ServerStandard|ServerDatacenter" {
                        ($Features | Where-Object { $_.Name -eq $Feature }).Installed | Should -Be $True
                    }
                }
            }
        }
    }
}

Describe -Tag 'Updates' "Windows update validation tests" {
    Context "Validate Cumulative updates" {
        It "Should have the latest Cumulative Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Cumulative Update."
            $LatestUpdate = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestCumulativeUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }

    Context "Validate Servicing Stack updates" {
        It "Should have the latest Servicing Stack Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Servicing Stack Update."
            $LatestUpdate = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestServicingStackUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }

    Context "Validate .NET Framework updates" {
        Write-Host -ForegroundColor Cyan "`n`tGetting latest .NET Framework Update."
        $Updates = Get-LatestNetFrameworkUpdate -OperatingSystem Windows10 | Where-Object { ($_.Architecture -eq $Proc) -and ($_.Version -eq "$Version") }
        ForEach ($Update in $Updates) {
            It "Should have the latest .NET Framework Update installed" {
                $Update.KB | Should -BeIn $InstalledUpdates.HotFixID
            }
        }
    }

    Context "Validate Adobe Flash updates" {
        It "Should have the latest Adobe Flash Player Update installed" {
            Write-Host -ForegroundColor Cyan "`n`tGetting latest Adobe Flash Player Update."
            $LatestUpdate = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version $Version | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            $PreviousUpdate = Get-LatestAdobeFlashUpdate -OperatingSystem Windows10 -Version $Version -Previous | Where-Object { $_.Architecture -eq $Proc } | Select-Object -Last 1
            If (($InstalledUpdates.HotFixID -match $LatestUpdate.KB) -or ($InstalledUpdates.HotFixID -match $PreviousUpdate.KB)) { $KBMatch = $True }
            $KBMatch | Should -BeTrue
        }
    }
}

Describe "Windows regional settings validation tests" {
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

Describe "Windows software validation tests" {
    Context "Validate installed Visual C++ Redistributables" {
        Write-Host -ForegroundColor Cyan "`n`tGetting installed Visual C++ Redistributables."
        $InstalledVcRedists = Get-InstalledVcRedist
        ForEach ($VcRedist in (Get-VcList -Release $VcReleases)) {
            It "Should have Visual C++ Redistributable $($VcRedist.Release) $($VcRedist.Architecture) $($VcRedist.Version) installed" {
                $Match = $InstalledVcRedists | Where-Object { ($_.Release -eq $VcRedist.Release) -and ($_.Architecture -eq $VcRedist.Architecture) }
                $Match.ProductCode | Should -Match $VcRedist.ProductCode
            }
        }
    }
}

Write-Host ""
