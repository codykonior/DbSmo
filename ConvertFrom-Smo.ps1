Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Import-Module SQLPS -DisableNameChecking
Set-Location C:\Temp

function Get-SmoDataSetType {
    [CmdletBinding()]    
    param (
        $TypeName
    )

    $typeList = @(
        "System.Boolean",
        "System.Byte[]",
        "System.Byte",
        "System.Char",
        "System.Datetime",
        "System.Decimal",
        "System.Double",
        "System.Guid",
        "System.Int16",
        "System.Int32",
        "System.Int64",
        "System.Single",
        "System.UInt16",
        "System.UInt32",
        "System.UInt64"
        )
    
    if ($typeList -contains $TypeName) {
        $TypeName
    } else {
        "System.String"
    }
} 

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
        "Server/Database/Events", # Not needed
        "Server/Database/ExtendedStoredProcedures", # Not needed
        "Server/Database/PartitionFunctions", # Not needed
        "Server/Database/PartitionSchemes", # Not needed
        "Server/Database/PlanGuides", # Not needed
        "Server/Database/Rules", # Not needed            
        "Server/Database/Schemas", # Not needed
        "Server/Database/Sequences", # Not needed
        # Service Broker - This leaves Queues, Routes, RemoteserviceBindings, and Priorities
        "Server/Database/ServiceBroker/MessageTypes", # Not needed
        "Server/Database/ServiceBroker/ServiceContracts", # Not needed
        "Server/Database/ServiceBroker/Services", # Not needed
        # Service Broker
        "Server/Database/StoredProcedures", # Not needed            
        "Server/Database/Synonyms", # Not needed
        "Server/Database/Tables", # Not needed
        "Server/Database/Triggers", # Not needed
        "Server/Database/UserDefined*", # Not needed
        "Server/Database/Views", # Not needed
        "Server/Database/XmlSchemaCollections", # Not needed
        
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

function ConvertFrom-Smo {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,
        [System.Data.DataSet] $OutputObject,
        [int] $Depth = -1,
        # If there's no Urn property on the object we received, these "prior" properties are used to construct a path for 
        # a) checking against exclusions and indirectly 
        # b) the table name
        [string] $ParentPath,
        [string] $ParentPropertyName,
        $ParentPrimaryKeyColumns,
        $MaxDepth = 10
    )

    if ($OutputObject -eq $null) {
        $OutputObject = New-Object System.Data.DataSet
        $OutputObject.EnforceConstraints = $false
    }
    
    $Depth++
    $tab = "`t" * $Depth

    # Do a depth check. If this triggered it would mean we did something really wrong because everything should be
    # accessible within the depth I've selected.
    if ($Depth -gt $maxDepth) {
        Write-Error "$($tab)Max depth exceeded, this shouldn't have happened..."
    }

    # Work out a "path". This is something like /Server/Database/User. We may get to some type which doesn't have
    # its own Urn so in those cases we can fall back to the parent path plus property name.
    if (!$InputObject.psobject.Properties["Urn"]) {
        if ($ParentPath -and $ParentPropertyName) {
            $path = "$path/$ParentPropertyName"
            Write-Verbose "$($tab)Working on prior $path"
        } else {
            Write-Error "$($tab)No Urn, and no parent details, this shouldn't have happened"
        }
    } else {
        $urn = $InputObject.Urn
        $path = $urn.XPathExpression.ExpressionSkeleton
        Write-Verbose "$($tab)Working on $urn, the skeleton path is $path"
    }

    # These are table renames
    switch ($path) {
        # Schedule = Server/JobServer/Job/SharedSchedule
        "Server/JobServer/Job/Schedule" {
            $tableName = "JobSchedule"
        }
        
        # Login = Server/Login 
        "Server/LinkedServer/Login" {
            $tableName = "LinkedServerLogin" # Server/Login goes under just Login
        }

        # Don't use DefaultLanguage
        "Server/Database/DefaultLanguage" {
            $tableName = "DatabaseDefaultLanguage"
        }
        "Server/Database/User/DefaultLanguage" {
            $tableName = "UserDefaultLanguage"
        }
        
        # Don't use ServiceBroker
        "Server/Database/ServiceBroker" {
            $tableName = "DatabaseServiceBroker"
        }
        "Server/Endpoint/ServiceBroker" {
            $tableName = "EndpointServiceBroker"
        }                

        # Don't use Role
        "Server/Role" {
            $tableName = "ServerRole"
        }
        "Server/Database/Role" {
            $tableName = "DatabaseRole"
        }

        # Cpus = Server/AffinityInfo/Cpus
        "Server/AffinityInfo/NumaNodes/Cpus" {
            $tableName = "NumaNodesCpus"
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/Schedulers/Cpu" {
            $tableName = "ResourcePoolCpus" # Not a typo, a standardization
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes/Cpus" {
            $tableName = "ResourcePoolNumaNodesCpus"
        }

        # NumaNodes = Server/AffinityInfo/NumaNodes
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes" {
            $tableName = "ResourcePoolNumaNodes"
        }

        # Don't use IPAddress
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress" {
            $tableName = "ServerProtocolIPAddress"
        }
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress/IPAddress" {
            $tableName = "ServerProtocolIPAddressDetail"
        }

        default {
            # Configuration entries all follow the same pattern. We flatten them into one table.
            if ($path -like "Server/Configuration/*") {
                $tableName = "Configuration" 
            } else {
                $tableName = $path -split "/" | Select -Last 1
            }
        }
    }           

    # We can pull out the existing table or create a new one
    if ($OutputObject.Tables[$tableName]) {
        Write-Verbose "$($tab)Retrieving table $tableName"
        $table = $OutputObject.Tables[$tableName]
    } else {
        Write-Verbose "$($tab)Adding table $tableName"
        $table = $OutputObject.Tables.Add($tableName)
    }

    # Create a row but this isn't added to the table until all properties (and sub properties) have been processed on the row.
    # But the row must be created BEFORE we calculate primary keys, so we can add the values for each key item.
    $row = $table.NewRow()

    # We need to populate primary keys (and add the columns if necessary)
    Write-Verbose "$($tab)Calculating primary keys"
    $primaryKeyColumns = @()
    $foreignKeyColumns = @()

    # Primary key constraints are only made on the Urn, even if it's not the most current one. We apply fixups later.
    for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
        $key = $urn.XPathExpression.Item($i)

        # Iterate through each part of the URN; e.g. the Server part, the Database part, the User part.
        foreach ($keyProperty in $key.FixedProperties.GetEnumerator()) {
            
            if ($i -eq ($urn.XPathExpression.Length - 1) -and $InputObject.psobject.Properties["Urn"]) {
                # If we are on the last part of the Urn, and the current row has a Urn, we use the proper name
                # (because this last name is the one that will be used on the current row as a property already)
                $keyPropertyName = $keyProperty.Name
            } else {
                # Otherwise we prefix names with the parent path name. We do this so that we don't get collisions
                # on things like Name; instead renaming them to ServerName, DatabaseName, etc, in the current row.
                # Also, if we were on the last step, but there is no Urn, then it means we still need to do this;
                # as the current row will be using a different current property name already, it's just not part
                # of the key yet (as far as we know, it will be "fixed" by adding it manually a bit later).
                $keyPropertyName = "$($key.Name)$($keyProperty.Name)"
            }
            # Examples:
            #   /Server Key = Name                
            #   /Server/Database Key = ServerName, Name
            #   /Server/Mail/MailProfile = ServerName, Name (as Mail does not have a key)
            #   /Server/Database/User/DefaultLanguage (no Urn) = ServerName, DatabaseName, UserName

            # This is the key itself
            $keyPropertyValue = $keyProperty.Value.Value

            if (!$table.Columns[$keyPropertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $keyPropertyName
                $column.DataType = switch ($keyProperty.Value.ObjType) { "String" { "System.String" } "Boolean" { "System.Boolean" } "Number" { "System.Int32" } } 
                if ($column.DataType -eq [string]) { # Not a bug, it really is equal, not is
                    $column.MaxLength = 128
                }
                $table.Columns.Add($column)

                Write-Verbose "$($tab)Key $keyPropertyName added"
            } else {
                Write-Verbose "$($tab)Key $keyPropertyName already exists"
            }
            $primaryKeyColumns += $table.Columns[$keyPropertyName]

            # Our local foreign key columns are everything except the last key (unless we have no Urn, in which case the last key doesn't exist yet)
            if ($i -ne ($urn.XPathExpression.Length - 1) -or !$InputObject.psobject.Properties["Urn"]) {
                $foreignKeyColumns += $table.Columns[$keyPropertyName]
            }

            if ($keyPropertyValue -eq $null) {
                Write-Error "$($tab)Null value in primary key, this shouldn't happen"
            } else {
                $row[$keyPropertyName] = $keyPropertyValue
            }
        }
    }
    # Finished looping primary keys

    # Get a list of properties to process; but remove the ones that match the wildcards in our exclusion list
    $properties = $InputObject.psobject.Properties | %{
        $propertyPath = "$path/$($_.Name)"

        if (!(ConvertFrom-SmoExclusions | Where { $propertyPath -like $_ })) {
            $_
        }
    }
    Write-Debug "$($tab)Properties $($properties | Select -ExpandProperty Name)"

    $recurseProperties = @()
    foreach ($property in $properties) {
        $propertyName = $property.Name
        $propertyType = $property.TypeNameOfValue

        # SMO has a bug which throws an exception if you try to iterate through this property.
        if ($propertyName -eq "OleDbProviderSettings" -and $propertyType -eq "Microsoft.SqlServer.Management.Smo.OleDbProviderSettingsCollection") {
            Write-Verbose "$($tab) Skipping $property because it's a bug"
            continue
        }

        # SMO throws an exception when it automatically creates some objects in collections, like Certificates, 
        # and you try to iterate through them without populating them first.
        if ($properties.psobject.Properties["State"] -and $properties.psobject.Properties["State"].Value -eq "Creating") {
            Write-Verbose "$($tab)Skipping $propertyName because it is not a real record"
            continue
        }

        # These are handled as properties on the main object, the real property collection doesn't need to be touched
        if ($propertyType -like "Microsoft.SqlServer.Management.Smo.*PropertyCollection") {
            Write-Verbose "$($tab)Completely skipping $propertyName as it is a property collection"
            continue
        }

        $propertyValue = $property.Value  

        # This addresses specific Server/Configuration entries which have not been filled out, causing an exception
        # when you add them to the table while constraints exist.
        if ($propertyType -eq "Microsoft.SqlServer.Management.Smo.ConfigProperty") { # It's important to use this instead of a check; because UserInstanceTimeout can be a Null value type
            if ($propertyValue -eq $null -or $propertyValue.Number -eq 0) {
                Write-Verbose "$($tab)Skipping config property $propertyName with value $propertyValue because it's invalid"
                continue
                # Exit to the caller immediately. We don't want to add this row or other properties to the table at all.
            } else {
                if ($propertyValue.DisplayName -eq "server trigger recursion") {
                    Write-Host "Next one!"
                }

                Write-Verbose "$($tab)Doing special for $propertyName collection"

                $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth $path $propertyName $parentPrimaryKeyColumns
                continue # We don't need it added to recursion
            }
        } elseif ($propertyValue -is [System.Collections.ICollection] -and $propertyType -ne "System.Byte[]") {
            Write-Verbose "$($tab)Processing property $propertyName collection"
        } else {
            if ($propertyName -eq "Configuration" -and $tableName -eq "Server") {
                Write-Verbose "Here"
            }
            
            # We can handle Byte[] as Varbinary, and we manually skip the collection portion/other properties later
            Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue"

            if (!$table.Columns[$propertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $propertyName
                $column.DataType = Get-SmoDataSetType $propertyType
                $table.Columns.Add($column)
            }

            # Go to the next variable if we have a null for the property; we don't want to try to read it below.
            # It can cause a failure in the ADO.NET translation, and also if we try to access the properties to
            # determine if it's a collection or not.
            if ($propertyValue -eq $null) {
                Write-Debug "$($tab)Skipping Null value"
                continue
            } else {
                $row[$propertyName] = $propertyValue
            
            }
        }

        $recurseProperties += $property
    }
    # Finished first round of adding properties and values

    # Do primary key fixups (additional key columns) for properties without a full Urn. this has to be done
    # after all of the properties have been looped above, otherwise the column won't exist yet (we could
    # create it but then we need to think of data types again, and duplicates effort).
    switch ($tableName) {
        "Configuration" {
            # Because we flattened it; it doesn't have a natural key
            $primaryKeyColumns += $table.Columns["Number"]
        }

        "Cpus" {
            # Because it doesn't have a Urn; Id is the Id of each single CPU
            $primaryKeyColumns += $table.Columns["Id"]
        }
        "NumaNodes" {
            # Because it doesn't have a Urn; Id is the Id of each single Numa Node
            $primaryKeyColumns += $table.Columns["Id"]
        }
        "NumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
        }

        "ResourcePoolCpus" {
            # Because it doesn't have a Urn. I think that Id is the Cpu Id in both columns but it wasn't clear.
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["Id"]
        }
        "ResourcePoolNumaNodes" {
            $primaryKeyColumns += $table.Columns["Id"]
        }
        "ResourcePoolNumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
        }

        "Schedulers" {
            $primaryKeyColumns += $table.Columns["Id"]
        }
    }

    # If there's no primary key on the table already then we'll add it
    try {
        if (!$table.PrimaryKey) {
            Write-Verbose "$($tab)Creating primary key"
            $table.Constraints.Add("PK_$tableName", $primaryKeyColumns, $true) | Out-Null
        
            # Check we have foreign keys to create (we wouldn't, for example, on Server) and that no foreign key exists yet.
            if ($foreignKeyColumns.Count -gt 0 -and !($table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint]})) {
                $foreignKeyName = "FK_$($tableName)_$($ParentPrimaryKeyColumns[0].Table.TableName)"
                Write-Verbose "$($tab)Creating foreign key $foreignKeyName"

                $foreignKeyConstraint = New-Object System.Data.ForeignKeyConstraint($foreignKeyName, $ParentPrimaryKeyColumns, $foreignKeyColumns)
                $table.Constraints.Add($foreignKeyConstraint) | Out-Null
            }
        }
    } catch {
        # Choke point for exceptions
        Write-Error "$($tab)Exception: $_"
    }

    # Part 2 is where we go through and start recursing things
    foreach ($property in $recurseProperties) {
        if ($property.Name -eq "Configuration") { 
                Write-Verbose "Here" 
        } 

        $propertyName = $property.Name
        $propertyValue = $property.Value  

        if ($propertyValue -is [System.Byte[]] -or 
            $propertyValue -is [System.DateTime] -or 
            $propertyValue -is [System.Enum] -or 
            $propertyValue -is [System.Guid] -or 
            $propertyValue -is [System.String] -or 
            $propertyValue -is [System.TimeSpan] -or 
            $propertyValue -is [System.Version] -or 
            ($propertyValue -is [System.Collections.ICollection] -and $propertyValue.Count -eq 0)
            ) {
            Write-Debug "$($tab)No recursion necessary; it's an empty collection or other simple type"
        } else {
            if (@($propertyValue.psobject.Properties).Count -gt 1) {
                if ($propertyValue -is [System.Collections.ICollection] -and $propertyValue.Count -gt 0) {
                    foreach ($item in $propertyValue.GetEnumerator()) {
                        Write-Verbose "$($tab)Recursing through collection"
                        $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $primaryKeyColumns
                    }
                } elseif ($tableName -eq "Configuration") {
                    # We have a special case for this. Because we're flattening it into one table, we need to pass
                    # the parent primary key columns, instead of our own.
                    foreach ($item in @($propertyValue)) {
                        Write-Verbose "$($tab)Recursing through array node"
                        $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $parentPrimaryKeyColumns
                    }    
                } elseif ($propertyValue -is [System.Array]) {
                    foreach ($item in @($propertyValue)) {
                        Write-Verbose "$($tab)Recursing through array node"
                        $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $primaryKeyColumns
                    }    
                } else {
                    Write-Verbose "$($tab)Recursing through non-array node"
                    $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth $path $propertyName $primaryKeyColumns
                }
            }
        }
    }
    # Finished looping properties
    
    # With the table columns defined, and primary keys defined, and row filled out, we can now add it to the table
    Write-Verbose "$($tab)Writing row for $tableName"
    try {
        $table.Rows.Add($row)
    } catch {
        # Choke point for exceptions
        Write-Error "$($tab)Exception: $_"
    }

    if ($table.Columns.Count -le $urn.XPathExpression.Length) {
        Write-Debug "$($tab)$tableName was empty except for keys"
    }

    Write-Verbose "$($tab)Return"
    $OutputObject
}
