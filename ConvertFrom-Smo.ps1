function ConvertFrom-Smo {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        $InputObject,
        [int] $MaxDepth = 10
    )

    Begin {
        # These are exclusions of property paths that fall into some sommon categories:
        #   Connect specific stuff that isn't needed
        #   SMO Bugs when accessing information
        #   Massive data transfers (system types, etc)
        #   Database-specific stuff (aside from the properties, users, and other things of general importance)
        #   Properties that are always empty or meaningless
        #   Properties that are duplicated elsewhere in the tree that we know about
        $excludePropertyPaths = @(
            "Server/ConnectionContext", # Not needed
            "Server/OleDbProviderSettings", # Buggy
            "Server/Languages", # Not needed
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
            # "Server/Database/ServiceBroker", # Not needed
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
            "Server/CollationID",
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

        function Recurse-Smo {
            [Cmdletbinding()]
            param (
                [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
                $InputObject,
                [System.Data.DataSet] $OutputObject,
                [int] $Depth = -1,
                # If there's no Urn property on the object we received, these "prior" properties are used to construct a path for 
                # a) checking against exclusions and indirectly 
                # b) the table name
                [string] $parentPath,
                [string] $parentPropertyName
            )
            
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
                if ($parentPath -and $parentPropertyName) {
                    $path = "$path/$parentPropertyName"
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
            # Create a row but this isn't added to the table until all properties (and sub properties) have been processed on the row
            $row = $table.NewRow()

            # Get a list of properties to process; but remove the ones that match the wildcards in our exclusion list
            $properties = $InputObject.psobject.Properties | %{
                $propertyPath = "$path/$($_.Name)"

                if (!($excludePropertyPaths | Where { $propertyPath -like $_ })) {
                    $_
                }
            }
            Write-Debug "$($tab)Properties $($properties | Select -ExpandProperty Name)"

            foreach ($property in $properties) {
                $propertyName = $property.Name
                $propertyType = $property.TypeNameOfValue

                # This fails if you try to resolve property.value
                if ($propertyName -eq "OleDbProviderSettings" -and $propertyType -eq "Microsoft.SqlServer.Management.Smo.OleDbProviderSettingsCollection") {
                    Write-Verbose "$($tab) Skipping $property because it's poisonous"
                    continue
                }

                if ($properties.psobject.Properties["State"] -and $properties.psobject.Properties["State"].Value -eq "Creating") {
                    Write-Verbose "$($tab)Skipping $propertyName because it has a Creating value which will throw errors"
                    continue
                }

                $propertyValue = $property.Value               
   
                # These are handled as properties on the main object, the real property collection doesn't need to be touched
                if ($propertyValue -and $propertyType -like "Microsoft.SqlServer.Management.Smo.*PropertyCollection") {
                    Write-Verbose "$($tab)Completely skipping $propertyName as it is a property collection"
                    continue
                }

                if ($propertyValue -is [Microsoft.SqlServer.Management.Smo.ConfigProperty]) {
                    if ($propertyValue.Number -eq 0) {
                        Write-Verbose "$($tab)Skipping config property $propertyName with value $propertyValue because it's invalid"
                        $OutputObject
                        return
                    }
                } elseif ($propertyType -like "Microsoft.SqlServer.Management.Smo.*" -and "$propertyValue" -eq $propertyType) {
                    Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue (matches type name)"
                } elseif ($propertyValue -is [System.Collections.ICollection]) {
                    Write-Verbose "$($tab)Processing property $propertyName collection"
                } else {
                    Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue"

                    if (!$table.Columns[$propertyName]) {
                        $column = New-Object System.Data.DataColumn
                        $column.ColumnName = $propertyName
                        $column.DataType = $propertyType
                        $table.Columns.Add($column)
                    }

                    if ($propertyValue -eq $null) {
                        Write-Debug "$($tab)Skipping Null value"
                        continue
                    } else {
                        $row[$propertyName] = $propertyValue
                    }
                }

                $isArray = @($propertyValue).Count -gt 0

                if ($propertyType -eq "System.Byte[]" -or 
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
                    $nextProperties = $propertyValue.psobject.Properties

                    if (@($nextProperties).Count -gt 1) {
                        if ($propertyValue -is [System.Collections.ICollection] -and $propertyValue.Count -gt 0) {
                            foreach ($item in $propertyValue.GetEnumerator()) {
                                Write-Verbose "$($tab)Recursing through collection"
                                $Output = Recurse-Smo $item $OutputObject $Depth $path $propertyName # -ColumnSet $ColumnSet
                            }
                        } elseif ($isArray) {
                            foreach ($item in @($propertyValue)) {
                                Write-Verbose "$($tab)Recursing through array node"
                                $Output = Recurse-Smo $item $OutputObject $Depth $path $propertyName # -ColumnSet $ColumnSet
                            }    
                        } else {
                            Write-Verbose "$($tab)Recursing through non-array node"
                            $OutputObject = Recurse-Smo $propertyValue $OutputObject $Depth $path $propertyName # -ColumnSet $ColumnSet
                        }
                    }
                }

                # End section for looping properties
            }

            # We need to populate primary keys (and add the columns if necessary)
            $primaryKeyColumns = @()
            $foreignKeyColumns = @() # This would be more complicated and isn't implemented yet
                
            # Primary key constraints are only made on the Urn, even if it's not the most current one. We apply fixups later.
            for ($i = 0; $i -lt $urn.XPathExpression.Length; $i++) {
                $key = $urn.XPathExpression.Item($i)

                # Iterate through each part of the URN; e.g. the Server part, the Database part, the User part.
                foreach ($property in $key.FixedProperties.GetEnumerator()) {
                    
                    if ($i -eq ($urn.XPathExpression.Length - 1) -and $InputObject.psobject.Properties["Urn"]) {
                        # If we are on the last part of the Urn, and the current row has a Urn, we use the proper Name
                        $propertyName = $property.Name
                    } else {
                        # Otherwise we prefix names with the parent path name
                        $propertyName = "$($key.Name)$($property.Name)"
                    }
                    # Examples:
                    #   /Server Key = Name                
                    #   /Server/Database Key = ServerName, Name
                    #   /Server/Database/User/DefaultLanguage (no Urn) = ServerName, DatabaseName, UserName (and where Name is non-Key and the language name)
                    #   /Server/Mail/MailProfile = ServerName, Name (as Mail does not have a key)

                    # This is the key itself
                    $propertyValue = $property.Value.Value

                    if (!$table.Columns[$propertyName]) {
                        $column = New-Object System.Data.DataColumn
                        $column.ColumnName = $propertyName
                        $column.DataType = switch ($property.Value.ObjType) { "String" { "System.String" } "Boolean" { "System.Boolean" } "Number" { "System.Int32" } } 
                        if ($column.DataType -eq [string]) { # Not a bug, it really is equal, not is
                            $column.MaxLength = 128
                        }
                        $table.Columns.Add($column)

                        Write-Verbose "$($tab)Key $propertyName added"
                    } else {
                        Write-Verbose "$($tab)Key $propertyName already exists"
                    }
                    $primaryKeyColumns += $table.Columns[$propertyName]

                    if ($propertyValue -eq $null) {
                        Write-Debug "$($tab)Skipping Null value"
                        continue
                    } else {
                        $row[$propertyName] = $propertyValue
                    }
                }
            }
            # Finished looping primary keys

            # If there's no primary key on the table already then we'll add it
            if (!$table.PrimaryKey) {
                # But first do fixups (additional key columns) for properties without a full Urn.
                switch ($tableName) {
                    "Configuration" {
                        $primaryKeyColumns += $table.Columns["Number"]
                    }

                    "Cpus" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }
                    "NumaNodes" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }
                    "NumaNodesCpus" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }

                    "ResourcePoolCpus" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }
                    "ResourcePoolNumaNodes" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }
                    "ResourcePoolNumaNodesCpus" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }

                    "Schedulers" {
                        $primaryKeyColumns += $table.Columns["ID"]
                    }
                }

                $table.Constraints.Add("PK_$tableName", $primaryKeyColumns, $true) | Out-Null
            }

            # With the table columns defined, and primary keys defined, and row filled out, we can now add it to the table
            Write-Verbose "$($tab)Writing row for $tableName"
            try {
                $table.Rows.Add($row)
            } catch {
                # Neither of these should occur. If they do it means we likely haven't accounted for duplicate table usage.
                if ($_.Exception.InnerException -is [System.Data.ConstraintException] -and $_.Exception.InnerException.Message -like "* is already present.") {
                    Write-Error "$($tab)Duplicate Exception: $_"
                } else {
                    Write-Error "$($tab)Add Exception: $_"
                }
            }

            if ($table.Columns.Count -le $urn.XPathExpression.Length) {
                Write-Debug "$($tab)$tableName was empty except for keys"
            }

            Write-Verbose "$($tab)Return"
            $OutputObject
        }
    }

    Process {
        $InputObject | %{
            Recurse-Smo $_ (New-Object System.Data.DataSet)
        }
    }
}
