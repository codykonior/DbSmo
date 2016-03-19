<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-SmoDatabaseSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Data.DataSet] $DataSet,
        [Parameter(Mandatory = $true)]
        $ServerInstance,
        [Parameter(Mandatory = $true)]
        $DatabaseName,
        [Parameter(Mandatory = $true)]
        $SchemaName,
        [switch] $Script
    )

    $scriptText = $()

    $sqlConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($ServerInstance)
    $sqlConnection.Connect()
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($sqlConnection)
    $sqlDatabase = $sqlServer.Databases[$databaseName]

    $newSchema = New-Object Microsoft.SqlServer.Management.Smo.Schema($sqlDatabase, $schemaName)
    $newSchema.Refresh()
    if ($Script) {
        Write-Log Trace $ServerInstance "Schema scripted"
        $scriptText += $newSchema.Script()
    } else {
        if ($newSchema.State -eq "Existing") {
            Write-Log Trace $ServerInstance "Schema altered"
            $newSchema.Alter()
        } else {
            Write-Log Trace $ServerInstance "Schema created"
            $newSchema.Create()
        }
    }

    $tables = @{}
    foreach ($table in $DataSet.Tables) {
        try {
            $tableName = $table.TableName
            Write-Log Trace $ServerInstance "Converting table $tableName"
            $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
            $newTable.Refresh() # This will fill the schema from the database if it already exists

            # Add temporal table columns if this is SQL 2016 onwards
            if ($newTable.Columns.Count -eq 0 -and $sqlConnection.ServerVersion.Major -ge 13) {
                Write-Log Trace $ServerInstance "Adding temporal fields"
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
            foreach ($column in ($table.Columns | Where { ($newTable.Columns | Select -ExpandProperty Name) -notcontains $_.ColumnName })) {
                $dataType = ConvertTo-SmoDataType $column.DataType.Name
                Write-Log Trace $ServerInstance "Adding column $($column.ColumnName) as $dataType"

                if ($dataType -eq "VarBinary" -or $dataType -eq "VarChar" -or $dataType -eq "NVarChar") {
                    if ($column.MaxLength -ne -1) {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, $column.MaxLength)
                    } else {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("$($dataType)Max")
                    }
                } elseif ($dataType -eq "Decimal" -and ($column.ColumnName -like "*LSN" -or $column.ColumnName -like "*LogSequenceNumber")) {
                    # These need to be of length 25, 0; the default is 19, 0.
                    #   Database.MirroringFailoverLogSequenceNumber
                    #   AvailabilityDatabase.RecoveryLSN 
                    #   AvailabilityDatabase.TruncationLSN 
                    #   DatabaseReplicaState.EndOfLogLSN 
                    #   DatabaseReplicaState.LastCommitLSN 
                    #   DatabaseReplicaState.LastHardenedLSN 
                    #   DatabaseReplicaState.LastReceivedLSN 
                    #   DatabaseReplicaState.LastRedoneLSN 
                    #   DatabaseReplicaState.LastSentLSN 
                    #   DatabaseReplicaState.RecoveryLSN 
                    #   DatabaseReplicaState.TruncationLSN 
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
                if (!($newTable.Indexes | Where { $_.IndexKeyType -eq "DriPrimaryKey" })) {
                    $primaryKeyName = $table.Constraints | Where { $_ -is [System.Data.UniqueConstraint] -and $_.IsPrimaryKey } | Select -ExpandProperty ConstraintName
                    Write-Log Trace $ServerInstance "Adding primary key $primaryKeyName"

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
                Write-Log Warn $ServerInstance "$tableName doesn't have a primary key!"
            }

            if ($changed) {
                # You must script out the table, the primary key, and the foreign keys separately
                if ($Script) {
                    Write-Log Trace $ServerInstance "Table scripted"
                    $scriptText += $newTable.Script()
                } else {
                    if ($newTable.State -eq "Existing") {
                        Write-Log Trace $ServerInstance "Table altered"
                        $newTable.Alter()
                    } else {
                        Write-Log Trace $ServerInstance "Table created"
                        $newTable.Create()
                    }
                }
            }
        } catch {
            Write-Log Error $ServerInstance "" $_
        }
    }

    foreach ($table in $DataSet.Tables) {
        $tableName = $table.TableName        
        $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
        $newTable.Refresh() # This will fill the schema from the database
        
        foreach ($constraint in ($table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint] -and ($newTable.ForeignKeys | Select -ExpandProperty Name) -notcontains $_.ConstraintName })) {
            try {
                $constraintName = $constraint.ConstraintName
                Write-Log Trace $ServerInstance "Adding foreign key $($tableName).$constraintName"

                $foreignKey = New-Object Microsoft.SqlServer.Management.Smo.ForeignKey($tables[$tableName], $constraintName)
                $foreignKey.ReferencedTable = $constraint.RelatedTable.TableName
                $foreignKey.ReferencedTableSchema = $SchemaName
                for ($i = 0; $i -lt $constraint.Columns.Count; $i++) {
                    $foreignKeyColumn = New-Object Microsoft.SqlServer.Management.Smo.ForeignKeyColumn($foreignKey, $constraint.Columns[$i], $constraint.RelatedColumns[$i])
                    $foreignKey.Columns.Add($foreignKeyColumn)
                }

                if ($Script) {
                    $scriptText += $foreignKey.Script()
                } else {
                    $foreignKey.Create()
                }
            } catch {
                Write-Log Error $ServerInstance "" $_
            }
        }
    }

    if ($Script) {
        $scriptText
    }
}
