<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-SmoPropertyExclusion {
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
        # Current connection settings
        "ManagedComputer/ConnectionSettings", # Wmi
        "Server/ConnectionContext", # Smo
        "Server/Database/ActiveConnections",
        "Server/Database/DboLogin",
        "Server/Database/DefaultSchema",
        "Server/Database/IsDbAccessAdmin",
        "Server/Database/IsDbBackupOperator",
        "Server/Database/IsDbDatareader",
        "Server/Database/IsDbDatawriter",
        "Server/Database/IsDbDdlAdmin",
        "Server/Database/IsDbDenyDatareader",
        "Server/Database/IsDbDenyDatawriter",
        "Server/Database/IsDbManager",
        "Server/Database/IsDbOwner",
        "Server/Database/IsDbSecurityAdmin",
        "Server/Database/IsLoginManager",

        # Standard, big, not useful, and empty settings
        "Server/Languages",
        "Server/ServiceMasterKey",
        "Server/SystemDataTypes",
        "Server/SystemMessages",

        # Application-specific information
        "Server/Database/Assemblies",
        "Server/Database/AsymmetricKeys",
        "Server/Database/DatabaseAuditSpecifications",
        "Server/Database/DatabaseEncryptionKey",
        "Server/Database/Defaults",
        "Server/Database/ExtendedStoredProcedures",
        "Server/Database/PartitionFunctions",
        "Server/Database/PartitionSchemes",
        "Server/Database/Rules", # These are an old kind of constraint            
        "Server/Database/Schemas",
        "Server/Database/Sequences",
        "Server/Database/StoredProcedures",            
        "Server/Database/Synonyms",
        "Server/Database/Tables",
        "Server/Database/Triggers",
        "Server/Database/UserDefined*",
        "Server/Database/UserName",
        "Server/Database/Views",
        "Server/Database/XmlSchemaCollections",

        # Deprecated and already in Server and Database respectively
        "Server/Information",
        "Server/Settings",
        "Server/Database/DatabaseOptions",
        # There is one caveat; while we exclude Server/Settings, in the code we redirect Server/OleDbProviderSettings
        # to the variable in Server/Settings/OleDbProviderSettings; because one works and the other doesn't. 

        # Generic SMO specific properties        
        "*/Events",
        "*/IsDesignMode",
        "*/Parent",
        "*/State",
        "*/Urn",
        "*/UserData"
    )

}
