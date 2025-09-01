# Scripts to Dynamically Create Security-enhanced Shares

[![License][license-badge]][license]

Scripts to configure secure permissions on shares for folder redirection and home drives etc.

For home drives, redirected folders, user profiles etc. it’s important to ensure folder permissions are set correctly. These permissions can be scripted for easy creation of these shares.

Based on recommendations set out in these articles:

* [How to dynamically create security-enhanced redirected folders by using folder redirection in Windows 2000 and in Windows Server 2003](https://support.microsoft.com/en-us/help/274443/how-to-dynamically-create-security-enhanced-redirected-folders-by-using-folder-redirection-in-windows-2000-and-in-windows-server-2003)
* [Deploy Folder Redirection with Offline Files](https://technet.microsoft.com/en-us/library/jj649078(v=ws.11).aspx)

## New-SecureShare.cmd

Batch file that demonstrates using ICACLS and NET SHARE commands to create a folder with secure permissions and share it.

## New-SecureShare.ps1

PowerShell approach to creating a folder with secure permissions and sharing the folder. Currently this script works locally, with remote support intended for a future release.

### Examples

Create a secure share for the folder E:\Home named Home, with Offline Settings set to automatic.

```powershell
.\New-SecureShare.ps1 -Path "E:\Home" -CachingMode Documents
```

Create a secure share for the folder E:\Profiles named Profiles, with Offline Settings set to none and sets a custom description.

```powershell
.\New-SecureShare.ps1 -Path "E:\Profiles" -Description "User roaming profiles"
```

[license-badge]: https://img.shields.io/github/license/aaronparker/secure-shares.svg?style=flat-square
[license]: https://github.com/aaronparker/secure-shares/blob/master/LICENSE
