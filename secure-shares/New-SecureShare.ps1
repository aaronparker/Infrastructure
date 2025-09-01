#Requires -Version 5
#Requires -RunAsAdministrator
<#PSScriptInfo
    .VERSION 2.0
    .GUID f5fcfeee-d09e-48ce-b0b7-c68e23d64f66
    .AUTHOR Aaron Parker
    .COMPANYNAME stealthpuppy
    .COPYRIGHT Aaron Parker, https://stealthpuppy.com
    .TAGS Secure Shares NTFS
    .LICENSEURI https://github.com/aaronparker/secure-shares/blob/master/LICENSE
    .PROJECTURI https://github.com/aaronparker/secure-shares/
    .ICONURI 
    .EXTERNALMODULEDEPENDENCIES 
    .REQUIREDSCRIPTS 
    .EXTERNALSCRIPTDEPENDENCIES 
    .RELEASENOTES
    .PRIVATEDATA
#>
<#
    .SYNOPSIS
        Create secure shared folders for home directories / redirected folders and profiles.
    
    .DESCRIPTION
        Create secure shared folders for home directories / redirected folders and profiles.
        
        Sources:
        https://support.microsoft.com/en-us/help/274443/how-to-dynamically-create-security-enhanced-redirected-folders-by-using-folder-redirection-in-windows-2000-and-in-windows-server-2003
        https://technet.microsoft.com/en-us/library/jj649078(v=ws.11).aspx

    .NOTES
        Name: New-SecureShare.ps1
        Author: Aaron Parker
        
    .LINK
        https://stealthpuppy.com

    .INPUTS
    
    .OUTPUTS

    .PARAMETER Path
        Specifies a local path to share.

    .PARAMETER Description
        Specifies a description for the share.

    .PARAMETER CachingMode
        Specifies the caching mode of the offline files for the SMB share. There are five caching modes:

            -- None. Prevents users from storing documents and programs offline.
            -- Manual. Allows users to identify the documents and programs they want to store offline.
            -- Programs. Automatically stores documents and programs offline.
            -- Documents. Automatically stores documents offline.
            -- BranchCache. Enables BranchCache and manual caching of documents on the shared folder.

    .EXAMPLE
        .\New-SecureShare.ps1 -Path "E:\Home" -CachingMode Documents

        Description:
        Creates a secure share for the folder E:\Home named Home, with Offline Settings set to automatic.

    .EXAMPLE
        .\New-SecureShare.ps1 -Path "E:\Profiles" -Description "User roaming profiles"

        Description:
        Creates a secure share for the folder E:\Profiles named Profiles, with Offline Settings set to none and sets a custom description.
#>
[CmdletBinding(SupportsShouldProcess = $true, HelpUri = 'https://github.com/aaronparker/secure-shares')]
[OutputType([System.Array])]
param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true,
        HelpMessage = 'Specify a target path for the share.')]
    [ValidateScript( {
            if ( -not ((Split-Path -Path $_) | Test-Path) ) {
                throw "Parent path $(Split-Path -Path $_) does not exist."
            }
            return $true
        })]
    [Alias('FullName', 'PSPath')]
    [System.String] $Path,

    [Parameter(Mandatory = $false, HelpMessage = 'Specify a description for the share.')]
    [System.String] $Description = "Secure share with access-based enumeration. Created with PowerShell.",

    [Parameter(Mandatory = $false, HelpMessage = 'Set the share caching mode. Use None for profile shares.')]
    [ValidateSet('None', 'Manual', 'Documents', 'Programs', 'BranchCache')]
    [System.String] $CachingMode = "None"
)

begin {
    # Trust the PowerShell Gallery
    function Install-PSGallery {
        [CmdletBinding(SupportsShouldProcess = $true)]
        param()
        if (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
            Write-Verbose -Message "Trusting the repository: PSGallery"
            if ($pscmdlet.ShouldProcess("NuGet", "Installing Package Provider")) {
                try {
                    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208
                }
                catch {
                    throw $_
                }
            }
            if ($pscmdlet.ShouldProcess("PowerShell Gallery", "Trusting PowerShell Repository")) {
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
        }
    }
}

process {
    # Get share name from $Path
    $share = $(Split-Path $Path -Leaf)
    if (Get-SmbShare -Name $share -ErrorAction "SilentlyContinue") {
        Write-Warning -Message "$share share already exists."
        Get-SmbShare -Name $share -ErrorAction "SilentlyContinue" | Select-Object -First 1
    }
    else {
        try {
            # Install the NTFSSecurity module from the PowerShell Gallery
            if (!(Get-Module -Name "NTFSSecurity")) {
                Install-PSGallery
                if ($pscmdlet.ShouldProcess("NTFSSecurity", "Installing module")) {
                    Install-Module -Name "NTFSSecurity" -ErrorAction "SilentlyContinue"
                }
            }
        }
        catch {
            Write-Error "Unable to install the module NTFSSecurity with error $_"
            break
        }

        # Create the folder
        try {
            if (!(Test-Path -Path $Path)) {
                if ($pscmdlet.ShouldProcess($Path, "Creating directory")) {
                    New-Item -Path $Path -ItemType "Directory" | Out-Null
                }
            }
        }
        catch {
            Write-Error "Failed to create folder $Path with error $_."
        }

        # Clear permissions on the path so that we can re-create secure permissions
        if ($pscmdlet.ShouldProcess($Path, "Clearing NTFS permissions")) {
            Clear-NTFSAccess -Path $Path -DisableInheritance
        }

        # Add NTFS permissions for securely creating shares
        # Administrators and System
        if ($pscmdlet.ShouldProcess($Path, "Adding 'Administrators', 'System' with Full Control")) {
            foreach ($account in 'Administrators', 'System') {
                $params = @{
                    Path         = $Path
                    Account      = $account
                    AccessRights = 'FullControl'
                }
                Add-NTFSAccess @params
            }
        }

        # Users - enable the ability to create a folder
        if ($pscmdlet.ShouldProcess($Path, "Adding 'Users' rights to create sub-folders")) {
            $params = @{
                Path         = $Path
                Account      = 'Users'
                AppliesTo    = 'ThisFolderOnly'
                AccessRights = @('CreateDirectories', 'ListDirectory', 'AppendData', 'Traverse', 'ReadAttributes')
            }
            Add-NTFSAccess @params
        }

        # Creator Owner - users then get full control on the folder they've created
        if ($pscmdlet.ShouldProcess($Path, "Adding 'CREATOR OWNER' with Full Control on sub-folders")) {
            $params = @{
                Path         = $Path
                Account      = 'CREATOR OWNER'
                AppliesTo    = 'SubfoldersAndFilesOnly'
                AccessRights = 'FullControl'
            }
            Add-NTFSAccess @params
        }

        # Share the folder with access-based enumeration
        if ($pscmdlet.ShouldProcess($Path, "Sharing")) {
            $params = @{
                Name                  = $share
                Path                  = $Path
                FolderEnumerationMode = 'AccessBased'
                FullAccess            = 'Administrators'
                ChangeAccess          = 'Authenticated Users'
                ReadAccess            = 'Everyone'
                CachingMode           = $CachingMode
                Description           = $Description
            }
            New-SMBShare @params
        }

        # Return share details (Get-SmbShare returns the shared folder twice)
        Get-SmbShare -Name $share -ErrorAction "SilentlyContinue" | Select-Object -First 1
    }
}
