<#
    .SYNOPSIS
        AppVeyor tests script.
#>
[OutputType()]
Param ()

# Invoke Pester tests
$res = Invoke-Pester -Path (Resolve-Path -Path $PWD) -OutputFormat NUnitXml -OutputFile (Join-Path (Resolve-Path -Path $PWD) -ChildPath "TestsResults.xml") -PassThru
If ($res.FailedCount -gt 0) { Throw "$($res.FailedCount) tests failed." }
