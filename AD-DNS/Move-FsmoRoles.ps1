# Moves all FSMO roles to the specified server
Move-ADDirectoryServerOperationMasterRole -Identity "dc2" –OperationMasterRole PDCEmulator,RIDMaster,InfrastructureMaster,SchemaMaster,DomainNamingMaster