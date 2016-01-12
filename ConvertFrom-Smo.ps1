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

    $writeRow = $true
    $recurseProperties = @()
    foreach ($property in $properties) {
        $propertyName = $property.Name
        $propertyType = $property.TypeNameOfValue

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
                Write-Verbose "$($tab)Skipping config property $propertyName with value $propertyValue because it's invalid"
                continue
            } else {
                Write-Verbose "$($tab)Processing config property $propertyName"

                $OutputObject = ConvertFrom-Smo $propertyValue $OutputObject $Depth $path $propertyName $parentPrimaryKeyColumns
                $writeRow = $false
                continue # We don't need it added to recursion, we do need to make sure the raw row is never added though
            }
        } elseif ($propertyValue -is [System.Collections.ICollection] -and $propertyValue -isnot [System.Byte[]]) {
            Write-Debug "$($tab)Processing property $propertyName collection"
            # We want to drop below to recurse properties

            if ($propertyValue.Count -eq 0) {
                continue # It's possible for it to be null, in which case, ew attempt to iterate later
            }
        } else {
            # We can handle [System.Byte[]] as Varbinary, and we manually skip the collection portion/other properties later
            Write-Verbose "$($tab)Processing property $propertyName with value $propertyValue"

            if (!$table.Columns[$propertyName]) {
                $column = New-Object System.Data.DataColumn
                $column.ColumnName = $propertyName

                # The ScriptProperty is just a workaround for IPAddressToString
                if (!(Get-SmoDataSetType $propertyType) -and $property.MemberType -ne "ScriptProperty") {
                    Write-Verbose "$($tab)Skipped writing out the raw column because it doesn't look right; it may be recursed instead"

                    if ($propertyValue -eq $null) {
                        continue
                    } else {
                        $recurseProperties += $property
                        continue
                    }
                } else {
                    try {
                        if ($property.MemberType -eq "ScriptProperty") {
                            $column.DataType = "System.String"
                        } else {
                            $column.DataType = Get-SmoDataSetType $propertyType
                        } 

                        $table.Columns.Add($column)
                    } catch {
                        Write-Verbose "Error $_"
                        Write-Error $_
                    }
                }
            }

            # Go to the next variable if we have a null for the property; we don't want to try to read it below.
            # It can cause a failure in the ADO.NET translation, and also if we try to access the properties to
            # determine if it's a collection or not.
            if ($propertyValue -eq $null) {
                Write-Debug "$($tab)Skipping Null value"
                continue
            } else {
                if ($propertyValue -isnot [System.DateTime] -or $propertyValue.Ticks -ne 0) { # Leave it null if this is the case, that's how SMO represents it
                    $row[$propertyName] = $propertyValue
                }

                ## Testing not recursing these again 
                continue
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

            Write-Error "Here 1"
        } else {
            ## Really need to check why/if this is needed
            try { 
                if ($propertyValue.psobject.Properties -and !(@($propertyValue.psobject.Properties).Count -gt 1)) {
                    Write-Error "Here 2"
                }
            } catch { 
                Write-Verbose "$($tab)Exception: $_"
                throw
            }

            if (@($propertyValue.psobject.Properties).Count -gt 1) {
                if ($propertyValue -is [System.Collections.ICollection]) {
                        Write-Verbose "$($tab)Recursing through collection"
                        try {
                            foreach ($item in $propertyValue.GetEnumerator()) {
                                $OutputObject = ConvertFrom-Smo $item $OutputObject $Depth $path $propertyName $primaryKeyColumns
                            }
                        } catch [Microsoft.SqlServer.Management.Sdk.Sfc.InvalidVersionEnumeratorException] {
                            # Happens when trying to access availability groups etc on a lower version
                        } catch [System.Data.SqlClient.SqlException] {
                            <# Number Class State = Message Number, Severity, State #>
                            try {
                                if ($_.Exception.InnerException.InnerException.Number -eq 954 -and $_.Exception.InnerException.InnerException.Class -eq 14 -and $_.Exception.InnerException.InnerException.State -eq 1) {
                                    Write-Verbose "$($tab)Couldn't get the data; $_"
                                } else {
                                    Write-Verbose "$($tab)Exception: $_"
                                    throw
                                }
                            } catch {
                                Write-Verbose "$($tab)Exception: $_"
                                throw                                
                            }
                        } catch {
                            Write-Verbose "$($tab)Exception: $_"
                            throw
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
            } else {
                Write-Error "Here 4"
            }
        }
    }
    # Finished looping properties

    # We set an exception not to write the row if it's part of the Configuration collection (as we write them separately)
    if ($writeRow) {
        Write-Verbose "$($tab)Writing row for $tableName"
        
        try {
            $table.Rows.Add($row)
        } catch {
            # Choke point for exceptions
            Write-Error "$($tab)Exception: $_"
        }
    }

    if ($table.Columns.Count -le $urn.XPathExpression.Length) {
        Write-Debug "$($tab)$tableName was empty except for keys"
    }

    Write-Verbose "$($tab)Return"
    $OutputObject
}
