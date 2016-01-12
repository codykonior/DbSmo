function ConvertFrom-SmoExclusions {
    [CmdletBinding()]
    param (
    )

    # These are exclusions of property paths that fall into some sommon categories:
    #   Connect specific stuff that isn't needed
    #   SMO Bugs when accessing information
    #   Massive data transfers (system types, etc)
    #   Database-specific stuff (aside from the properties, users, and other things of general importance)
    #   Properties that are always empty or meaningless
    #   Properties that are duplicated elsewhere in the tree that we know about
    @(
        "Server/ConnectionContext", # Not needed
        "Server/OleDbProviderSettings", # Buggy
        "Server/Languages", # Not needed
        "Server/ServiceMasterKey", # Empty
        "Server/SystemDataTypes", # Not needed
        "Server/SystemMessages", # Not needed       

        "Server/Database/ActiveConnections", # Not needed
        "Server/Database/Assemblies", # Not needed
        "Server/Database/AsymmetricKeys", # Not needed
        "Server/Database/DatabaseAuditSpecifications", # Not needed
        "Server/Database/DatabaseEncryptionKey", # Not needed
        "Server/Database/DboLogin", # Not needed
        "Server/Database/Defaults", # Not needed
        "Server/Database/DefaultSchema", # Not needed
        "Server/Database/ExtendedStoredProcedures", # Not needed
        "Server/Database/IsDbAccessAdmin", # Not needed
        "Server/Database/IsDbBackupOperator", # Not needed
        "Server/Database/IsDbDatareader", # Not needed
        "Server/Database/IsDbDatawriter", # Not needed
        "Server/Database/IsDbDdlAdmin", # Not needed
        "Server/Database/IsDbDenyDatareader", # Not needed
        "Server/Database/IsDbDenyDatawriter", # Not needed
        "Server/Database/IsDbManager", # Not needed
        "Server/Database/IsDbOwner", # Not needed
        "Server/Database/IsDbSecurityAdmin", # Not needed
        "Server/Database/IsLoginManager", # Not needed
        "Server/Database/PartitionFunctions", # Not needed
        "Server/Database/PartitionSchemes", # Not needed
        # Not normally needed but maybe you want to know all your servers that use them...
        # "Server/Database/PlanGuides", # Not needed
        "Server/Database/Rules", # Not needed, these are an old kind of constraint            
        "Server/Database/Schemas", # Not needed
        "Server/Database/Sequences", # Not needed
        <#
        # I think this should be Queues, Services, Routes, but until I'm sure...
        "Server/Database/ServiceBroker/MessageTypes", # Not needed
        "Server/Database/ServiceBroker/Priorities", # Not needed
        "Server/Database/ServiceBroker/RemoteServiceBindings", # Not needed
        "Server/Database/ServiceBroker/ServiceContracts", # Not needed
        #>

        "Server/Database/StoredProcedures", # Not needed            
        "Server/Database/Synonyms", # Not needed
        "Server/Database/Tables", # Not needed
        "Server/Database/Triggers", # Not needed
        "Server/Database/UserDefined*", # Not needed
        "Server/Database/UserName", # Not needed
        "Server/Database/Views", # Not needed
        "Server/Database/XmlSchemaCollections", # Not needed
        
        "*/Events", # Event notification, not needed
        "*/IsDesignMode", # Not needed
        "*/Parent", # Prevent recursion
        "*/State", # Not needed
        "*/Urn", # Flattened elsewhere
        "*/UserData", # Empty

        # These are duplicated in the System/Information schema; $smo.Information.psobject.Properties | Select -ExpandProperty Name | Sort | %{ "`"Server/$_`"," } 
        "Server/BuildClrVersion",
        "Server/BuildClrVersionString",
        "Server/BuildNumber",
        "Server/Collation",
        "Server/CollationId",
        "Server/ComparisonStyle",
        "Server/ComputerNamePhysicalNetBIOS",
        "Server/Edition",
        "Server/EngineEdition",
        "Server/ErrorLogPath",
        "Server/FullyQualifiedNetName",
        "Server/IsCaseSensitive",
        "Server/IsClustered",
        "Server/IsFullTextInstalled",
        "Server/IsHadrEnabled",
        "Server/IsSingleUser",
        "Server/IsXTPSupported",
        "Server/Language",
        "Server/MasterDBLogPath",
        "Server/MasterDBPath",
        "Server/MaxPrecision",
        "Server/NetName",
        "Server/OSVersion",
        "Server/Parent",
        "Server/PhysicalMemory",
        "Server/Platform",
        "Server/Processors",
        "Server/Product",
        "Server/ProductLevel",
        "Server/Properties",
        "Server/ResourceLastUpdateDateTime",
        "Server/ResourceVersion",
        "Server/ResourceVersionString",
        "Server/RootDirectory",
        "Server/SqlCharSet",
        "Server/SqlCharSetName",
        "Server/SqlSortOrder",
        "Server/SqlSortOrderName",
        "Server/State",
        "Server/Urn",
        "Server/UserData",
        "Server/Version",
        "Server/VersionMajor",
        "Server/VersionMinor",
        "Server/VersionString",

        # Wmi
        "ManagedComputer/ConnectionSettings"
    )

}