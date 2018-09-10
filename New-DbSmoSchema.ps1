<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function New-DbSmoSchema {
    [CmdletBinding(DefaultParameterSetName = "ServerInstance")]
    param (
        [Parameter(Mandatory = $true)]
        [System.Data.DataSet] $DataSet,

        [Parameter(Mandatory = $true, ParameterSetName = "ServerInstance")]
        $ServerInstance,
        [Parameter(Mandatory = $true, ParameterSetName = "ServerInstance")]
        $DatabaseName,
        [Parameter(ParameterSetName = "Connection")]
        $Connection,

        $SchemaName,
        [switch] $Script
    )

    $scriptText = New-Object System.Collections.ArrayList

    if ($PSCmdlet.ParameterSetName -eq "Connection") { 
        $sqlConnection = $Connection
        $DatabaseName = $sqlConnection.Database

        $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($sqlConnection)
    } else {
        $sqlConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $sqlConnection.ConnectTimeout = 60
        $sqlConnection.ServerInstance = $ServerInstance
        $sqlConnection.DatabaseName = $DatabaseName
        $sqlConnection.Connect()
        $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($sqlConnection)
    }

    $sqlDatabase = $sqlServer.Databases[$DatabaseName]
    $newSchema = New-Object Microsoft.SqlServer.Management.Smo.Schema($sqlDatabase, $schemaName)
    $newSchema.Refresh()
    if ($Script) {
        Write-Verbose "Schema scripted"
        [void] $scriptText.Add($newSchema.Script())
    } else {
        if ($newSchema.State -eq "Existing") {
            Write-Verbose "Schema altered"
            $newSchema.Alter()
        } else {
            Write-Verbose "Schema created"
            $newSchema.Create()
        }
    }

    $tables = @{}
    foreach ($table in $DataSet.Tables) {
        try {
            $tableName = $table.TableName
            Write-Verbose "Converting table $tableName"
            $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
            $newTable.Refresh() # This will fill the schema from the database if it already exists

            # Add temporal table columns if this is SQL 2016 onwards
            if ($newTable.Columns.Count -eq 0 -and ([version] $sqlConnection.ServerVersion).Major -ge 13) {
                Write-Verbose "Adding temporal fields"
                $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("DateTime2", 2)
                $fromColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($newTable, "_ValidFrom", $dataType)
                $fromColumn.Nullable = $false # Columns belonging to a system-time period cannot be nullable.
                $fromColumn.IsHidden = $true                
                $fromColumn.GeneratedAlwaysType = "AsRowStart"
                $newTable.Columns.Add($fromColumn)

                $toColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($newTable, "_ValidTo", $dataType)
                $toColumn.Nullable = $false # Columns belonging to a system-time period cannot be nullable.
                $toColumn.IsHidden = $true
                $toColumn.GeneratedAlwaysType = "AsRowEnd"
                $newTable.Columns.Add($toColumn)
                
                $newTable.AddPeriodForSystemTime("_ValidFrom", "_ValidTo", $true) # If you accidentally passed non strings you get a "must provide existing column" error

                $newTable.HistoryTableSchema = $SchemaName
                $newTable.HistoryTableName = "$($tableName)_History"
                $newTable.IsSystemVersioned = $true
            }

            # Iterate columns where the column names aren't already in the table
            $changed = $false
            foreach ($column in ($table.Columns | Where-Object { ($newTable.Columns | Select-Object -ExpandProperty Name) -notcontains $_.ColumnName })) {
                $dataType = switch ($column.DataType.Name) {  
                    "Boolean" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::Bit
                    }  
                    "Byte[]" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::VarBinary
                    }
                    "Byte"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::TinyInt
                    }  
                    "DateTime"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::DateTime2
                    }     
                    "Decimal" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal
                    }  
                    "Double" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::Float
                    }  
                    "Guid" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::UniqueIdentifier
                    }  
                    "Int16"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt
                    }  
                    "Int32"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::Int
                    }  
                    "Int64" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt
                    }  
                    "UInt16"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt
                    }  
                    "UInt32"  {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt # Cluster.RootMemoryReserved; ClusterNode.DrainTarget; ClusterGroup.FailoverThreshold
                    }  
                    "UInt64" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt
                    }  
                    "Single" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal
                    }
                    "String" {
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::NVarChar
                    }
                    default {
                        # This basically defaults everything else so that if we passed something we really
                        # didn't expect then we won't be storing a raw object; it'll be cast to string.
                        [Microsoft.SqlServer.Management.Smo.SqlDataType]::NVarChar
                    }  
                }  
                Write-Verbose "Adding column $($column.ColumnName) as $dataType"

                if ($dataType -eq "VarBinary" -or $dataType -eq "VarChar" -or $dataType -eq "NVarChar") {
                    if ($column.MaxLength -ne -1) {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, $column.MaxLength)
                    } else {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("$($dataType)Max")
                    }
                } elseif ($dataType -eq "Decimal") {
                    # The only known uses of Decimal in SMO are for LSN. It defaults to 18, 0 but we need 25, 0.
                    # AvailabilityDatabase.RecoveryLSN
                    # AvailabilityDatabase.TruncationLSN
                    # Database.MirroringFailoverLogSequenceNumber
                    # DatabaseReplicaState.EndOfLogLSN
                    # DatabaseReplicaState.LastCommitLSN
                    # DatabaseReplicaState.LastHardenedLSN
                    # DatabaseReplicaState.LastReceivedLSN
                    # DatabaseReplicaState.LastRedoneLSN
                    # DatabaseReplicaState.LastSentLSN
                    # DatabaseReplicaState.RecoveryLSN
                    # DatabaseReplicaState.TruncationLSN
                    $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, 25, 0)
                } else {
                    $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType)
                }
    
                $newColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($newTable, $column.ColumnName, $dataType)
                $newColumn.Nullable = $column.AllowDbNull
                $newTable.Columns.Add($newColumn)

                $changed = $true
            }
            $tables.Add($tableName, $newTable)

            # If the SMO table has a primary key but the new/existing table doesn't
            if ($table.PrimaryKey) {
                if (!($newTable.Indexes | Where-Object { $_.IndexKeyType -eq "DriPrimaryKey" })) {
                    $primaryKeyName = $table.Constraints | Where-Object { $_ -is [System.Data.UniqueConstraint] -and $_.IsPrimaryKey } | Select-Object -ExpandProperty ConstraintName
                    Write-Verbose "Adding primary key $primaryKeyName"

                    $primaryKey = New-Object Microsoft.SqlServer.Management.Smo.Index($newTable, $primaryKeyName)
                    $primaryKey.IndexType = [Microsoft.SqlServer.Management.Smo.IndexType]::ClusteredIndex
                    $primaryKey.IndexKeyType = [Microsoft.SqlServer.Management.Smo.IndexKeyType]::DriPrimaryKey

                    foreach ($column in $table.PrimaryKey) {
                        $indexColumn = New-Object Microsoft.SqlServer.Management.Smo.IndexedColumn($primaryKey, $column.ColumnName)
                        $primaryKey.IndexedColumns.Add($indexColumn)
                    }

                    $newTable.Indexes.Add($primaryKey)
                }
            } else {
                Write-Warning "$tableName doesn't have a primary key!"
            }

            if ($changed) {
                # You must script out the table, the primary key, and the foreign keys separately
                if ($Script) {
                    Write-Verbose "Table scripted"
                    [void] $scriptText.Add($newTable.Script())
                } else {
                    if ($newTable.State -eq "Existing") {
                        Write-Verbose "Table altered"
                        $newTable.Alter()
                    } else {
                        Write-Verbose "Table created"
                        $newTable.Create()
                    }
                }
            }
        } catch {
            throw
        }
    }

    foreach ($table in $DataSet.Tables) {
        $tableName = $table.TableName        
        $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
        $newTable.Refresh() # This will fill the schema from the database
        
        foreach ($constraint in ($table.Constraints | Where-Object { $_ -is [System.Data.ForeignKeyConstraint] -and ($newTable.ForeignKeys | Select-Object -ExpandProperty Name) -notcontains $_.ConstraintName })) {
            try {
                $constraintName = $constraint.ConstraintName
                Write-Verbose "Adding foreign key $($tableName).$constraintName"

                $foreignKey = New-Object Microsoft.SqlServer.Management.Smo.ForeignKey($tables[$tableName], $constraintName)
                $foreignKey.ReferencedTable = $constraint.RelatedTable.TableName
                $foreignKey.ReferencedTableSchema = $SchemaName
                for ($i = 0; $i -lt $constraint.Columns.Count; $i++) {
                    $foreignKeyColumn = New-Object Microsoft.SqlServer.Management.Smo.ForeignKeyColumn($foreignKey, $constraint.Columns[$i], $constraint.RelatedColumns[$i])
                    $foreignKey.Columns.Add($foreignKeyColumn)
                }

                if ($Script) {
                    [void] $scriptText.Add($foreignKey.Script())
                } else {
                    $foreignKey.Create()
                }
            } catch {
                throw
            }
        }
    }

    if ($Script) {
        $scriptText
    }
}
