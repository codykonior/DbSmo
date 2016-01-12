<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-SmoInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $ServerInstance,

        [Parameter(Mandatory = $true)]
        $SaveServerInstance,
        [Parameter(Mandatory = $true)]
        $SaveDatabase,

        [switch] $Smo = $true,
        $SmoSchemaName = "smo",
        [switch] $Wmi = $false,
        $WmiSchemaName = "wmi"
    )

    $performance = @{}
    $startDate = Get-Date
    Write-Verbose "Started $ServerInstance at $startDate"

    $smoObjects = @()
    if ($Smo) {
        $smoObjects += @{ SchemaName = $SmoSchemaName; Value = (New-Object Microsoft.SqlServer.Management.Smo.Server($ServerInstance)); }
    }
    if ($Wmi) {
        $smoObjects += @{ SchemaName = $WmiSchemaName; Value = (New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer($ServerInstance)); }
    }

    foreach ($smoObject in $smoObjects) {
        $schemaName = $smoObject.SchemaName
        $dataSet = ConvertFrom-Smo $smoObject.Value
        try {
            $dataSet.EnforceConstraints = $true
        } catch {
            $dataSet.Tables | %{ 
                if ($_.GetErrors()) { 
                    $_.TableName
                    $_.GetErrors()
                }
            }
            Write-Error "Exception: $_"
        }

        Add-SmoDatabaseSchema $dataSet $SaveServerInstance $SaveDatabase $schemaName 

        $bulkCopyConnection = New-Object System.Data.SqlClient.SqlConnection("Server=$SaveServerInstance;Database=$SaveDatabase;Trusted_Connection=true")
        $bulkCopyConnection.Open()
        $bulkCopyTransaction = $bulkCopyConnection.BeginTransaction($ServerInstance.Substring(0, [Math]::Min($ServerInstance.Length, 32)))
        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($bulkCopyConnection, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $bulkCopyTransaction)

        try {
            foreach ($table in $dataSet.Tables) {
                Write-Verbose "Saving $($table.TableName)"
                $bulkCopy.DestinationTableName = "[$schemaName].[$($table.TableName)]"

                # Required in case we've added columns, they will not be in order, and as long as you specify the names here it will all work okay
                $bulkCopy.ColumnMappings.Clear()
                $table.Columns | %{ 
                    $bulkCopy.ColumnMappings.Add((New-Object System.Data.SqlClient.SqlBulkCopyColumnMapping($_.ColumnName, $_.ColumnName))) | Out-Null
                }
                $bulkCopy.WriteToServer($table)
            }
        } catch {
            $bulkCopyTransaction.Rollback()
            Write-Error "Exception: $_"
        } finally {
            if ($bulkCopyTransaction.Connection -ne $null) {
                $bulkCopyTransaction.Commit()
            }
        }

        $endDate = Get-Date
        Write-Verbose "Finished $ServerInstance at $endDate"
        $performance.Add($ServerInstance, $endDate - $startDate)
    }

    $performance
}
