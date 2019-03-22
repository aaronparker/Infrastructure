test-wsman -ComputerName hv1.home.stealthpuppy.com -Authentication Default

Invoke-Command -ComputerName hv1.home.stealthpuppy.com { Measure-Command { gwmi Win32_PerfRawData_PerfOS_Memory } | fl sec*,mill* }

New-Item -Path $pshome\Modules\BNTools\BNTools.psm1 -Type file -Force -OutVariable bnmod 
notepad $bnmod


$servers = 'dc1', 'sql1', 'xd71', 'appv1'
$cred = Get-Credential 'home\administrator'
$servers | % { Copy-Item -Recurse -Force -Verbose -Path $pshome\Modules\BNTools -Destination \\$_\c$\Windows\System32\WindowsPowerShell\v1.0\Modules }

$cred = Get-Credential 'hv1\administrator'
Invoke-Command -Credential $cred -ComputerName $servers -ScriptBlock { if ((Get-ExecutionPolicy) -ne 'RemoteSigned') { Set-ExecutionPolicy RemoteSigned -Force } }
Invoke-Command -Credential $cred -ComputerName $servers -ScriptBlock { Get-ExecutionPolicy } | ft pscomp*,value -auto

Invoke-Command -Credential $cred -ComputerName $servers -ScriptBlock { ipmo bntools; Get-Memory -Detailed -Format }


Invoke-Command -Credential $cred -ComputerName $servers -HideComputerName -ScriptBlock { ipmo bntools; Get-Memory -Format } | select * -excl run* | sort 'Use%' -Descending | Out-GridView -Title 'Server Memory Stats'



set-item WSMAN:\localhost\client\trustedhosts -value dc1 -concatenate -force