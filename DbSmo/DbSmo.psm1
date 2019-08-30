[CmdletBinding()]
param (
    [bool] $Debugging
)

# Because these are set once in a script scope (modules and functions are all considered in one script scope)
# they will be effective in every function, and won't override or be overridden by changes in parent scopes.
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constrained endpoint compatibility
Set-Alias -Name Exit-PSSession -Value Microsoft.PowerShell.Core\Exit-PSSession
Set-Alias -Name Get-Command -Value Microsoft.PowerShell.Core\Get-Command
Set-Alias -Name Get-FormatData -Value Microsoft.PowerShell.Utility\Get-FormatData
Set-Alias -Name Get-Help -Value Microsoft.PowerShell.Core\Get-Help
Set-Alias -Name Measure-Object -Value Microsoft.PowerShell.Utility\Measure-Object
Set-Alias -Name Out-Default -Value Microsoft.PowerShell.Core\Out-Default
Set-Alias -Name Select-Object -Value Microsoft.PowerShell.Utility\Select-Object

if ($Debugging) {
    foreach ($fileName in (Get-ChildItem $PSScriptRoot "*-*.ps1" -Recurse -Exclude "*.Steps.ps1", "*.Tests.ps1", "*.ps1xml")) {
        try {
            Write-Verbose "Loading function from path '$fileName'."
            . $fileName.FullName
        } catch {
            Write-Error $_
        }
    }
} else {
    $scriptBlock = Get-ChildItem $PSScriptRoot "*-*.ps1" -Recurse -Exclude "*.Steps.ps1", "*.Tests.ps1", "*.ps1xml" | ForEach-Object {
        [System.IO.File]::ReadAllText($_.FullName)
    }
    $ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($scriptBlock), $null, $null)
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

    # Read the strings only instead
    "Server/AvailabilityGroup/AvailabilityReplica/ReadOnlyRoutingList",
    "Server/AvailabilityGroup/AvailabilityReplica/LoadBalancedReadOnlyRoutingList",

    # This is temporarily broken
    "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/Schedulers/Cpu"
)

Set-Variable -Scope Script -Option Constant -Name DbSmoPropertyExclusions -Value @("ConnectionContext", "ExecutionManager", "Events", "IsDesignMode", "Parent", "State", "Urn", "UserData" <#  ProcessorUsage often throws exceptions #>, "ParentCollection")
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
    "System.Version",
    "Microsoft.SqlServer.Management.Common.ServerVersion"
)
