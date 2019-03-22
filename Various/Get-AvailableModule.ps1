Function Get-AvailableModule {
    Param ([string]$Name)
    If ( -Not (Get-Module -Name $Name)) {
        If (Get-Module -ListAvailable | Where-Object { $_.Name -eq $Name }) {
            Import-Module -Name $Name
            Return $True
            # If module available then import
        } Else {
            Return $False
            # Module not available
        }
    } Else {
        Return $True
        # Module already loaded
    }
} #End Function