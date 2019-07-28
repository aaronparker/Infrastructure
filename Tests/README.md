# Operating System Validation

[Pester](https://github.com/pester/Pester/wiki) tests used to validate a Windows Server or Windows 10 operating system install. Tests can be used to validate a specific Windows configuration to ensure it's ready for deployment. Tests could be run manually or at the end of an install (e.g. via MDT) to ensure the Windows image meets the expected configuration.

## Running Tests

Tests can be run with the `Invoke-Pester` command:

```powershell
Invoke-Pester -Script .\Windows101903.Tests.ps1 -OutputFormat NUnitXml -OutputFile .\TestResults.xml
```

The output should look similar to the screenshot below:

![Pester output](https://raw.githubusercontent.com/aaronparker/Infrastructure/master/Tests/PesterOutput.PNG)
