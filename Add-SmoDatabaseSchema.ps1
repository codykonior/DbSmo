function ConvertFrom-DataSet {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $ServerInstance,
        [Parameter(Mandatory = $true)]
        $DatabaseName,
        [Parameter(Mandatory = $true)]
        $SchemaName,
        [Parameter(Mandatory = $true)]
        [System.Data.DataSet] $DataSet,
        [switch] $Script
    )

    $scriptText = $()

    $sqlConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($ServerInstance)
    $sqlConnection.Connect()
    $sqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($sqlConnection)
    $sqlDatabase = $sqlServer.Databases[$databaseName]

    $tables = @{}
    foreach ($table in $DataSet.Tables) {
        try {
            $tableName = $table.TableName
            Write-Verbose "Processing table $tableName"
            $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
            $newTable.Refresh() # This will fill the schema from the database if it already exists

            # Iterate columns where the column names aren't already in the table
            $changed = $false
            foreach ($column in ($table.Columns | Where { ($newTable.Columns | Select -ExpandProperty Name) -notcontains $_.ColumnName })) {
                Write-Verbose "Adding column $($column.ColumnName)"
                $dataType = ConvertFrom-DataType $column.DataType.Name
                if ("VarBinary", "VarChar" -contains $dataType) {
                    if ($column.MaxLength -ne -1) {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType, $column.MaxLength)
                    } else {
                        $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType("$($dataType)Max")
                    }
                } else {
                    $dataType = New-Object Microsoft.SqlServer.Management.Smo.DataType($dataType)
                }
    
                $newColumn = New-Object Microsoft.SqlServer.Management.Smo.Column($newTable, $column.ColumnName, $dataType)
                $newColumn.Nullable = $column.AllowDbNull
                $newTable.Columns.Add($newColumn)

                $changed = $true
            }
            $tables.Add($tableName, $newTable)

            if ($changed) {
                # You must script out the table, the primary key, and the foreign keys separately
                if ($Script) {
                    Write-Verbose "Table Scripted"
                    $scriptText += $newTable.Script()
                } else {
                    if ($newTable.State -eq "Existing") {
                        Write-Verbose "Table Altered"
                        $newTable.Alter()
                    } else {
                        Write-Verbose "Table Created"
                        $newTable.Create()
                    }
                }
            }

            # If the SMO table has a primary key but the new/existing table doesn't
            if ($table.PrimaryKey) {
                if (!($newTable.Indexes | Where { $_.IndexKeyType -eq "DriPrimaryKey" })) {
                    try { $primaryKeyName = $table.Constraints | Where { $_ -is [System.Data.UniqueConstraint] -and $_.IsPrimaryKey } | Select -ExpandProperty ConstraintName
                    } catch { 
                    $_ 
                    } 
                    Write-Verbose "Adding primary key $primaryKeyName"

                    $primaryKey = New-Object Microsoft.SqlServer.Management.Smo.Index($newTable, $primaryKeyName)
                    $primaryKey.IndexType = [Microsoft.SqlServer.Management.Smo.IndexType]::ClusteredIndex
                    $primaryKey.IndexKeyType = [Microsoft.SqlServer.Management.Smo.IndexKeyType]::DriPrimaryKey

                    foreach ($column in $table.PrimaryKey) {
                        $indexColumn = New-Object Microsoft.SqlServer.Management.Smo.IndexedColumn($primaryKey, $column.ColumnName)
                        $primaryKey.IndexedColumns.Add($indexColumn)
                    }
        
                    if ($Script) {
                        $scriptText += $primaryKey.Script()
                    } else {
                        $primaryKey.Create()
                    }
                }
            } else {
                Write-Verbose "Warning: $tableName doesn't have a primary key!"
            }
        } catch {
            Write-Error $_
        }
    }

    foreach ($table in $DataSet.Tables) {
        $tableName = $table.TableName        
        $newTable = New-Object Microsoft.SqlServer.Management.Smo.Table($sqlDatabase, $tableName, $SchemaName)
        $newTable.Refresh() # This will fill the schema from the database
        
        foreach ($constraint in ($table.Constraints | Where { $_ -is [System.Data.ForeignKeyConstraint] -and ($newTable.ForeignKeys | Select -ExpandProperty Name) -notcontains $_.ConstraintName })) {
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
                    $scriptText += $foreignKey.Script()
                } else {
                    $foreignKey.Create()
                }
            } catch {
                Write-Error $_
            }
        }
    }

    if ($Script) {
        $scriptText
    } else {
        $tables.GetEnumerator() | %{
            $_.Value
        }
    }
}