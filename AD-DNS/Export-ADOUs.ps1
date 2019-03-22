# http://c-nergy.be/blog/?p=4709
Get-ADOrganizationalUnit -filter {name -like "*"} | Select Name, DistinguishedName | export-csv AD_OU_Tree.csv -NoTypeInformation