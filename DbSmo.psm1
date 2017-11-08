[CmdletBinding()] 
param(
)

# Because these are set once in a script scope (modules and functions are all considered in one script scope)
# they will be effective in every function, and won't override or be overridden by changes in parent scopes.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

foreach ($fileName in (Get-ChildItem $PSScriptRoot "*.ps1" -Recurse)) {
    try {
	    Write-Verbose "Loading function from path '$fileName'."
	    .$fileName.FullName
    } catch {
	    Write-Error $_
    }
}

Set-Variable -Scope Script -Option Constant -Name DbSmoPathExclusions -Value @(
        # Current connection settings
        "ManagedComputer/ConnectionSettings", # Wmi only
        "ManagedComputer/Service/Dependencies", # Fatally broken, returns nothing useful

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

        # SQL 2017 - useless
        "Server/SupportedAvailabilityGroupClusterTypes",

        # Standard, big, not useful, and empty settings
        "Server/Languages",
        "Server/ServiceMasterKey",
        "Server/SystemDataTypes",
        "Server/SystemMessages",
        
        # Extremely time consuming for little gain
        "Server/Database/ServiceBroker",

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
        "Server/Database/UserDefinedTypes",
        "Server/Database/UserDefinedAggregates",
        "Server/Database/UserDefinedFunctions",
        "Server/Database/UserDefinedDataTypes",
        "Server/Database/UserDefinedTableTypes",
        "Server/Database/UserName",
        "Server/Database/Views",
        "Server/Database/XmlSchemaCollections",

        # Deprecated and already in Server and Database respectively
        "Server/Information",
        "Server/Settings",
        "Server/Database/DatabaseOptions"
        # There is one caveat; while we exclude Server/Settings, in the code we redirect Server/OleDbProviderSettings
        # to the variable in Server/Settings/OleDbProviderSettings; because one works and the other doesn't. 
    )

Set-Variable -Scope Script -Option Constant -Name DbSmoPropertyExclusions -Value @("ConnectionContext", "ExecutionManager", "Events", "IsDesignMode", "Parent", "State", "Urn", "UserData" <#  ProcessorUsage often throws exceptions #>)
    # ConnectionContext was in SMO 2014; ExecutionManager is another wrapper in SMO 2016

Set-Variable -Scope Script -Option Constant -Name DataTypeSimple -Value @(
	"System.Boolean",
        "System.Byte",
        "System.Byte[]",
        "System.Char",
        "System.DateTime",
        "System.Decimal",
        "System.Double",
        "System.Guid",
        "System.Int16",
        "System.Int32",
        "System.Int64",
        "System.Single",
	    "System.String",
        "System.UInt16",
        "System.UInt32",
        "System.UInt64"
        )

Set-Variable -Scope Script -Option Constant -Name DataTypeString -Value @(
	"System.Enum",
	"System.Timespan",
	"System.Version"
	)
