# http://c-nergy.be/blog/?p=4709
Get-ADOrganizationalUnit -filter { name -like "*" } | select Name, DistinguishedName | Export-Csv AD_OU_Tree.csv -NoTypeInformation