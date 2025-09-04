function remove-itembyage {
    <#
        .SYNOPSIS
            remove items from folders recursively.
 
        .DESCRIPTION
            this function removes items older than a specified age from the target folder
 
        .PARAMETER Days
            Specifies the amount of days since the file was last written to you wish to filter on.
 
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
 
http://blog.stealthpuppy.com/user-virtualization/profile-clean-up-script-powershell-edition/
 
    #>
 
    [cmdletbinding(SupportsShouldProcess = $True)]
    param(
        [Parameter(Mandatory = $true, Position = 0, HelpMessage = "Number of days to filter by, E.G. ""14""")]
        [int]$days,
        [Parameter(Mandatory = $true, Position = 1, HelpMessage = "Path to files you wish to delete")]
        [string]$path,
        [string]$typefilter,
        [switch]$silent)
 
    #check for silent switch
    if ($silent) { $ea = "Silentlycontinue" }
    Else { $ea = "Continue" }
 
    #check for typefilter, creates an array if specified.
    if (!($typefilter)) { $filter = "*" }
    Else { $filter = foreach ($item in $typefilter.split(",")) { $item.insert(0, "*.") } }
 
    if (Test-Path $path) {
        $now = Get-Date
        $datefilter = $now.adddays(-$days)
        foreach ($file in Get-ChildItem "$path\*" -Recurse -Force -Include $filter | where { $_.PSIsContainer -eq $false -and $_.lastwritetime -le $datefilter -and $_.name -ne "desktop.ini" }) {
            if (!($silent)) { Write-Host "Deleting: $($file.fullname)" }
            Remove-Item -LiteralPath $file.fullname -Force -ea $ea
        }#end for
    }#end if
 
    Else {
        if (!($silent)) { Write-Warning "the path specified does not exist! ($path)" }
    }#end else
}#end function
 
#Get KnownFolder Paths
$appdata = $env:appdata
$Cookies = (New-Object -com shell.application).namespace(289).Self.Path
$History = (New-Object -com shell.application).namespace(34).Self.Path
$recent = (New-Object -com shell.application).namespace(8).Self.Path
$profile = $env:userprofile
 
#commands
remove-itembyage -days 0 -path $appdata -typefilter "txt,log" -silent
remove-itembyage -days 90 -path $cookies -silent
remove-itembyage -days 14 -path $recent -silent
remove-itembyage -days 21 -path $history -silent
remove-itembyage -days 14 -path "$appdata\Microsoft\office\Recent" -silent
