<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function ConvertFrom-Smo {
    [Cmdletbinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $InputObject,
        [System.Data.DataSet] $OutputObject,
        [int] $Depth = 0,
        # If there's no Urn property on the object we received, these "prior" properties are used to construct a path for 
        # a) checking against exclusions and indirectly 
        # b) the table name
        [string] $SubstitutePath,
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
        Write-Error "Max depth exceeded, this shouldn't have happened..."
    }

    # Work out a "path". This is something like /Server/Database/User. We may get to some type which doesn't have
    # its own Urn so in those cases we can fall back to the parent path plus property name.
    if (!$InputObject.psobject.Properties["Urn"]) {
        $path = $SubstitutePath
        Write-Verbose "$($tab)Working on substitute path of $path"
    } else {
        $urn = $InputObject.Urn
        $path = $urn.XPathExpression.ExpressionSkeleton
        Write-Verbose "$($tab)Working on $urn, the skeleton path is $path"
    }

    # These are table renames for conflicts and readability. I don't think it will work if you renamed 
    # one that has a foreign key dependency on it though. If you really wanted to do this you'd need
    # to work out how to make sub tables pick up this name; it gets extracted from the Urn which is why
    # it wouldn't work. Unless we switched that to use the path instead, and overwrote the path; here
    # and on the sub tables. I don't do that because splitting on the path breaks easily because it's
    # based on / which can show in lots of properties. The XPath doesn't have this issue. But we could
    # convert the $path variable to an array instead and then join it for comparisons.
    #
    # On second thoughts, the past primary key is fine. The new foreign key is fine. The foreign key
    # name is fine (it gets the name from the foreign key table). All that would be wrong is the name
    # of the new key for the foreign key because it's based on the XPath not on the past table name.
    # That could be fixed easily...
    #
    # These only rename TABLES, not PROPERTIES.
    $performancePath = Get-Date
    switch ($path) {
        "Server/Configuration" {
            $tableName = "ServerConfiguration"
            break
        }

        # Rename for readability
        "Server/Mail/ConfigurationValue" {
            $tableName = "MailConfigurationValue"
            break
        }

        # Rename for readability
        "Server/UserOption" {
            $tableName = "ServerUserOption"
            break
        }

        # Schedule = Server/JobServer/Job/SharedSchedule
        "Server/JobServer/Job/Schedule" {
            $tableName = "JobSchedule"
            break
        }
        
        # Login = Server/Login 
        "Server/LinkedServer/Login" {
            $tableName = "LinkedServerLogin" # Server/Login goes under just Login
            break
        }

        "Server/Database/Certificate" {
            $tableName = "DatabaseCertificate"
            break
        }
        "Server/Database/SymmetricKey" {
            $tableName = "DatabaseSymmetricKey"
            break
        }
        "Server/Database/DefaultFullTextLanguage" {
            $tableName = "DatabaseDefaultFullTextLanguage"
            break
        }


        # Don't use DefaultLanguage
        "Server/Database/DefaultLanguage" {
            $tableName = "DatabaseDefaultLanguage"
            break
        }
        "Server/Database/User/DefaultLanguage" {
            $tableName = "UserDefaultLanguage"
            break
        }
        
        # Don't use ServiceBroker
        "Server/Database/ServiceBroker" {
            $tableName = "DatabaseServiceBroker"
            break
        }
        "Server/Endpoint/ServiceBroker" {
            $tableName = "EndpointServiceBroker"
            break
        }                

        # Don't use Role
        "Server/Role" {
            $tableName = "ServerRole"
            break
        }
        "Server/Database/Role" {
            $tableName = "DatabaseRole"
            break
        }

        # Cpus = Server/AffinityInfo/Cpus
        "Server/AffinityInfo/NumaNodes/Cpus" {
            $tableName = "NumaNodesCpus"
            break
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/Schedulers" {
            $tableName = "ResourcePoolSchedulers" # Not a typo, a standardization
            break
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/Schedulers/Cpu" {
            $tableName = "ResourcePoolSchedulersCpus" # Not a typo, a standardization
            break
        }
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes/Cpus" {
            $tableName = "ResourcePoolNumaNodesCpus"
            break
        }

        # NumaNodes = Server/AffinityInfo/NumaNodes
        "Server/ResourceGovernor/ResourcePool/ResourcePoolAffinityInfo/NumaNodes" {
            $tableName = "ResourcePoolNumaNodes"
            break
        }

        # Don't use IPAddress
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress" {
            $tableName = "ServerProtocolIPAddress"
            break
        }
        "ManagedComputer/ServerInstance/ServerProtocol/IPAddress/IPAddress" {
            $tableName = "ServerProtocolIPAddressDetail"
            break
        }

        # Readability
        "Server/JobServer/Job/Step" {
            $tableName = "JobStep"
            break
        }
        "Server/Endpoint/Payload" {
            $tableName = "EndpointPayload"
            break
        }
        "Server/Endpoint/Soap" {
            $tableName = "EndpointSoap"
            break
        }
        "Server/Endpoint/DatabaseMirroring" {
            $tableName = "EndpointDatabaseMirroring"
            break
        }
        "Server/Endpoint/Protocol" {
            $tableName = "EndpointProtocol"
            break
        }
        "Server/Endpoint/Http" {
            $tableName = "EndpointHttp"
            break
        }
        "Server/Endpoint/Tcp" {
            $tableName = "EndpointTcp"
            break
        }
        "Server/Endpoint/Tcp/ListenerIPAddress" {
            $tableName = "EndpointListenerIPAddress"
            break
        }
        
        
        "Server/JobServer/Schedule" {
            $tableName = "JobServerSchedule"
            break
        }
        "Server/JobServer/ProxyAccount" {
            $tableName = "JobServerProxyAccount"
            break
        }
        "Server/JobServer/AlertSystem" {
            $tableName = "JobServerAlertSystem"
            break
        }
        "Server/JobServer/JobCategory" {
            $tableName = "JobServerJobCategory"
            break
        }
        "Server/JobServer/Alert" {
            $tableName = "JobServerAlert"
            break
        }
        "Server/JobServer/Operator" {
            $tableName = "JobServerOperator"
            break
        }
        "Server/JobServer/AlertCategory" {
            $tableName = "JobServerAlertCategory"
            break
        }
        "Server/JobServer/OperatorCategory" {
            $tableName = "JobServerOperatorCategory"
            break
        }
        
        "Server/ResourceGovernor/ResourcePool/WorkloadGroup" {
            $tableName = "ResourcePoolWorkloadGroup"
            break
        }
       
        "ManagedComputer/Service/Dependencies" {
            $tableName = "ServiceDependencies"
            break
        }

        "Server/Database/FileGroup/File" {
            $tableName = "DatabaseFile"
            break
        }
        "Server/Database/LogFile" {
            $tableName = "DatabaseLogFile"
            break
        }
        "Server/Database/FileGroup" {
            $tableName = "DatabaseFileGroup"
            break
        }

        # Enum methods
        "Server/Database/User/EnumRoles" {
            $tableName = "UserRole"
            break
        }
        "Server/Database/User/EnumObjectPermissions" {
            $tableName = "UserPermission"
            break
        }
        "Server/Database/User/EnumObjectPermissions/PermissionType" { # Child of above
            $tableName = "UserPermissionType"
            break
        }
        "Server/Role/EnumMemberNames" { # EnumServerRoleMembers is deprecated
            $tableName = "ServerRoleMember"
            break
        }
        "Server/Role/EnumObjectPermissions" {
            $tableName = "ServerRolePermission"
            break
        }
        "Server/Login/EnumObjectPermissions" {
            $tableName = "LoginPermission"
            break
        }

        default {
            # Configuration entries all follow the same pattern. We flatten them into one table.
            if ($path -like "Server/Configuration/*") {
                $tableName = "ServerConfiguration" 
            } else {
                $tableName = $path -split "/" | Select -Last 1
            }
        }
    }           
    "(Path Switch)" | Add-PerformanceRecord $performancePath

    # We can pull out the existing table or create a new one
    if ($OutputObject.Tables[$tableName]) {
        Write-Verbose "$($tab)Retrieving table $tableName"
        $table = $OutputObject.Tables[$tableName]
    } else {
        Write-Verbose "$($tab)Adding table $tableName"
        $table = $OutputObject.Tables.Add($tableName)
    }

    # We need to populate primary keys (and add the columns if necessary)
    Write-Verbose "$($tab)Preparing primary keys"
    $performancePrimaryKey = Get-Date

    # Create a row but this isn't added to the table until all properties (and sub properties) have been processed on the row.
    # But the row must be created BEFORE we calculate primary keys, so we can add the values for each key item.
    $row = $table.NewRow()

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

                $parentColumn = $ParentPrimaryKeyColumns[$primaryKeyColumns.Count]
                if (($ParentPrimaryKeyColumns[0].Table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint] } | Select -ExpandProperty Columns) -contains $parentColumn) {
                    $keyPropertyName = $parentColumn.ColumnName
                } else {
                    $keyPropertyName = "$($ParentPrimaryKeyColumns[0].Table.TableName)$($parentColumn.ColumnName)"
                }
            }
            # Examples:
            #   /Server Key = Name                
            #   /Server/Database Key = ServerName, Name
            #   /Server/Mail/MailProfile = ServerName, Name (as Mail does not have a key)
            #   /Server/Database/User/DefaultLanguage (no Urn) = ServerName, DatabaseName, UserName

            # This is the key itself
            $keyPropertyValue = $keyProperty.Value.Value
            # The Xml parser does not propery decode the additional quotations; for example on a Step.JobName
            if ($keyPropertyValue -is [string]) {
                $keyPropertyValue = $keyPropertyValue.Replace("''", "'")
            }

            if (!$table.Columns[$keyPropertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $keyPropertyName
                # It recognises all of these automatically Number but I populate them for prosperity anyway
                $column.DataType = switch ($keyProperty.Value.ObjType) { "String" { "System.String" } "Boolean" { "System.Boolean" } "Number" { "System.Int32" } } 
                # Not a bug, use -eq instead of -is
                if ($column.DataType -eq [string]) { 
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
                Write-Error "Null value in primary key, this shouldn't happen"
            } else {
                $row[$keyPropertyName] = $keyPropertyValue
            }
        }
    }
    # Finished looping primary keys

    "(Primary Key)" | Add-PerformanceRecord $performancePrimaryKey
    $performanceProperties = Get-Date

    # Get a list of properties to process; but remove the ones that match the wildcards in our exclusion list
    $performanceExclude = Get-Date
    $properties = $InputObject.psobject.Properties | Where { $SmoDbPropertyExclusions -notcontains $_.Name -and $SmoDbPathExclusions -notcontains "$path/$($_.Name)" }
    "(Performance Exclude)" | Add-PerformanceRecord $performanceExclude
    # Write-Debug "$($tab)Properties $($properties | Select -ExpandProperty Name)"

    $writeRow = $true
    $recurseProperties = @()

    <#
    # Make sure never to remove the Enum* part or we'd be calling random methods!
    $InputObject.psobject.Methods | Where { $_.Name -Like "Enum*" } | %{
        if ($path -eq "Server/Database/User" -and @("EnumRoles", "EnumObjectPermissions") -contains $_.Name) {
            $recurseProperties += $_
        }

        if ($path -eq "Server/Login" -and @("EnumObjectPermissions") -contains $_.Name) {
            $recurseProperties += $_
        }

        if ($path -eq "Server/Role" -and @("EnumMemberNames", "EnumObjectPermissions") -contains $_.Name) {
            $recurseProperties += $_
        }
    }
    #>

    foreach ($property in $properties) {
        $propertyName = $property.Name
        $propertyType = $property.TypeNameOfValue

        # These are handled as properties on the main object, the real property collection doesn't need to be touched
        if ($propertyType.StartsWith("Microsoft.SqlServer.Management.Smo.") -and $propertyType.EndsWith("PropertyCollection")) {
            Write-Debug "$($tab)Completely skipping $propertyName as it is a property collection"
            continue
        }
        # SMO has a bug which throws an exception if you try to iterate through this property. Instead we redirect it to use
        # the one in Server/Settings which is more reliable. We already did the exclusion check so it's not impacted here.
        if ($propertyName -eq "OleDbProviderSettings" -and $propertyType -eq "Microsoft.SqlServer.Management.Smo.OleDbProviderSettingsCollection") {
            $property = $InputObject.Settings.psobject.Properties["OleDbProviderSettings"]
        }

        $propertyValue = $property.Value  

        # This addresses specific Server/Configuration entries which have not been filled out, causing an exception
        # when you add them to the table while constraints exist.
        if ($propertyType -eq "Microsoft.SqlServer.Management.Smo.ConfigProperty") { # It's important to use this instead of a check; because UserInstanceTimeout can be a Null value type
            if ($propertyValue -eq $null -or $propertyValue.Number -eq 0) {
                Write-Debug "$($tab)Skipping config property $propertyName with value $propertyValue because it's invalid"
                continue
            } else {
                Write-Debug "$($tab)Processing config property $propertyName"
                
                $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth "$path/$propertyName" $parentPrimaryKeyColumns
                $writeRow = $false
                continue
                # We don't return because we want to continue processing all of the other properties in this way.
                # However we also don't want to write the row at the end because it's empty, so we set a special flag 
                # not to.
            }
        } elseif ($propertyValue -is [System.Collections.ICollection] -and $propertyValue -isnot [System.Byte[]]) {
            Write-Debug "$($tab)Processing property $propertyName collection"

            # It's possible for it to be null, which is okay, and worth trying to iterate... maybe... I should test this
            if ($propertyValue.Count -eq 0) {
                continue
            }
          
            $recurseProperties += $property
            continue
        } else {
            # We can handle [System.Byte[]] as Varbinary, and we manually skip the collection portion/other properties later
            if (!$table.Columns[$propertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $propertyName
                
                # When adding a column don't jump directly to checking $propertyValue as it may still be null.

                if ($property.MemberType -eq "ScriptProperty") { # Used on IpAddressToString
                    $columnDataType = "System.String"
                } else {
                    $columnDataType = ConvertFrom-DataType $propertyType
                }
                if (!$columnDataType) {
                    # If we don't haev the right data type, then we can't, by definition, add the column
                    Write-Debug "$($tab)Skipped writing out the raw column because it doesn't look right; it may be recursed instead"

                    if ($propertyValue -eq $null) {
                        continue
                    } else {
                        $recurseProperties += $property
                        continue
                    }
                }

                $column.DataType = $columnDataType
                $table.Columns.Add($column)
            }

            # If it's null we don't need to set it because it defaults to [DBNull]::Value anyway (probably). Also, always
            # maybe sure to check -(n)e(q) $null because $propertyValue could be a boolean, and false's would then not be
            # written out.
            if ($propertyValue -ne $null) {
                Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue"
    
	        	# This is how SMO represents null dates; a 0000 date or a 1900 date. Both are converted to null.
                if ($propertyValue -isnot [System.DateTime] -or @(599266080000000000, 0) -notcontains $propertyValue.Ticks) {
                    $row[$propertyName] = $propertyValue
                }
            }
        }
    }
    # Finished first round of adding properties and values
    "(Properties)" | Add-PerformanceRecord $performanceProperties
    $path | Add-PerformanceRecord $performanceProperties
    $performanceConstraints = Get-Date

    # Do primary key fixups (additional key columns) for properties without a full Urn. this has to be done
    # after all of the properties have been looped above, otherwise the column won't exist yet (we could
    # create it but then we need to think of data types again, and duplicates effort).
    switch ($tableName) {
        "ServerConfiguration" {
            # Because we flattened it; it doesn't have a natural key
            $primaryKeyColumns += $table.Columns["Number"]
            break
        }

        "Cpus" {
            # Because it doesn't have a Urn; Id is the Id of each single CPU
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "NumaNodes" {
            # Because it doesn't have a Urn; Id is the Id of each single Numa Node
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "NumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
            break
        }

        "ResourcePoolSchedulers" {
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "ResourcePoolSchedulersCpus" {
            # Because it doesn't have a Urn. I think that Id is the Cpu Id in both columns but it wasn't clear.
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["Id"]
            break
        }
        "ResourcePoolNumaNodes" {
            $primaryKeyColumns += $table.Columns["Id"]
            break
        }
        "ResourcePoolNumaNodesCpus" {
            $primaryKeyColumns += $table.Columns["Id"]
            $foreignKeyColumns += $table.Columns["NumaNodeId"]
            break
        }
    }

    # If there's no primary key on the table already then we'll add it
    try {
        if (!$table.PrimaryKey) {
            Write-Verbose "$($tab)Creating primary key"
            [void] ($table.Constraints.Add("PK_$tableName", $primaryKeyColumns, $true))
        
            # Check we have foreign keys to create (we wouldn't, for example, on Server) and that no foreign key exists yet.
            if ($foreignKeyColumns -and !($table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint]})) {
                $foreignKeyName = "FK_$($tableName)_$($ParentPrimaryKeyColumns[0].Table.TableName)"
                Write-Verbose "$($tab)Creating foreign key $foreignKeyName"

                $foreignKeyConstraint = New-Object System.Data.ForeignKeyConstraint($foreignKeyName, $ParentPrimaryKeyColumns, $foreignKeyColumns)
                [void] ($table.Constraints.Add($foreignKeyConstraint))
            }
        }
    } catch {
        # Choke point for exceptions
        throw
    }
    "(Constraints)" | Add-PerformanceRecord $performanceConstraints

    # Part 2 is where we go through and start recursing things
    foreach ($property in $recurseProperties) {
        $propertyType = $property.MemberType
        $propertyName = $property.Name
        $propertyValue = $property.Value
        
        if ($propertyType -eq "Method") {
<#            # For additional safety, make sure it enumerates something
            if ($propertyName -like "Enum*") {
                Write-Verbose "$($tab)Processing $propertyName as a method"
                foreach ($item in $propertyValue.Invoke()) {
                    $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth "$path/$propertyName" $primaryKeyColumns
                }
            }
            #>
        } elseif ($propertyValue -is [System.Collections.ICollection]) {
            Write-Verbose "$($tab)Recursing through $propertyName as a collection"

            try {
                foreach ($item in $propertyValue.GetEnumerator()) {
                    $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth "$path/$propertyName" $primaryKeyColumns
                }
            } catch {
                if (Test-Error Microsoft.SqlServer.Management.Sdk.Sfc.InvalidVersionEnumeratorException) {
                    # e.g. Availability Groups on lower versions of SQL Server
                    Write-Verbose "$($tab)Property collection not valid on this version."
                } elseif (Test-Error System.UnauthorizedAccessException) {
                    throw (New-Object System.Exception "Administrator (or other) permission required to use WMI.", $_.Exception)
                } elseif (Test-Error @{ ErrorCode = "InvalidNamespace" }) {
                    throw (New-Object System.Exception "SMO is unable to find WMI endpoint; this could be the SMO 2016 -> 2014/2012 bug, SMO 2014 -> 2012 bug, or SQL Server < 2005 (not supported by SMO).", $_.Exception)
                } elseif (Test-Error @{ Number = 927; Class = 14; State = 2 }) {
                    Write-Verbose "$($tab)Unable to examine the database in detail because it's currently restoring."
                } elseif (Test-Error @{ Number = 942; Class = 14; State = 4 }) {
                    Write-Verbose "$($tab)Unable to examine the database in detail because it's offline."
                } elseif (Test-Error @{ Number = 945; Class = 14; State = 2 }) {
                    Write-Verbose "$($tab)Unable to examine the database in detail probably because it's part of a mirror/AG and restoring."
                } elseif (Test-Error @{ Number = 954; Class = 14; State = 1 }) {
                    Write-Verbose "$($tab)Unable to examine the database in detail because it's part of a mirror/AG."
                } elseif (Test-Error @{ Number = 978; Class = 14; State = 1 }) {
                    Write-Verbose "$($tab)Unable to examine the database in detail because it's part of a AG and has read-intent only."
                } elseif (Test-Error @{ Number = 3906; Class = 16; State = 1 }) {
                    Write-Verbose "$($tab)Unable to examine this item in detail because the database is read only (often Full-Text catalogs on a secondary in a mirror/AG)."
                } elseif (Test-Error @{ TargetSite = "System.String GetDbCollation(System.String)" }) {
                    Write-Verbose "$($tab)Likely a database has been set offline but believes it is configured for Auto_Close when it's not. Set the database online, re-disable Auto_Close (even if it's not set), set it back offline. Sometimes the error remains though."
                } else {
                    throw
                }
            }
        } else {
            Write-Verbose "$($tab)Recursing through $propertyName as a non-collection"
            $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth "$path/$propertyName" $primaryKeyColumns
        }
    }
    # Finished looping properties

    # We set an exception not to write the row if it's part of the ServerConfiguration collection (as we write them separately)
    if ($writeRow) {
        Write-Verbose "$($tab)Writing row for $tableName"
        
        try {
            $table.Rows.Add($row)
        } catch {
            # Choke point for exceptions
            throw
        }
    }

    Write-Verbose "$($tab)Return"
    $OutputObject
}
