<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Write-DbSmoData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        $DataSet,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ServerInstance,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $SchemaName
    )

    try {
        $DataSet.EnforceConstraints = $true
    } catch {
        $failures = $DataSet.Tables | ForEach-Object {
            if ($_.GetErrors()) {
                "Table: $($_.TableName)"
                "Errors:"
                $_.GetErrors()
            }
        } | Out-String

        throw "Enforcing constraints failed. What follows are the tables and rows involved: $failures"
    }

    New-DbSmoSchema -DataSet $DataSet -ServerInstance $ServerInstance -DatabaseName $DatabaseName -SchemaName $SchemaName

    $baseTableName = $DataSet.Tables[0].TableName
    # To bulk copy we need proper schema and table names
    $DataSet.Tables | ForEach-Object {
        $_.TableName = "[$SchemaName].[$($_.TableName)]"
    }

    Use-DbRetry {
        try {
            $smo = Get-DbSmo $ServerInstance
            # Delete
            if ($smo.Version.Major -lt 14) {
                Add-DbDeleteTemporalProcedure $ServerInstance $DatabaseName $SchemaName
                $dbData = New-DbConnection $ServerInstance $DatabaseName | New-DbCommand "EXEC [dbo].[DeleteTemporal] @SchemaName = @SchemaName, @TableName = @TableName, @ColumnName = 'Name', @Value = @Value;" -Parameters @{ SchemaName = $SchemaName; TableName = $baseTableName; Value = $dataSet.Tables[0].Rows[0].Name; } | Enter-DbTransaction -PassThru
            } else {
                $dbData = New-DbConnection -ServerInstance $ServerInstance -DatabaseName $DatabaseName | New-DbCommand "DELETE FROM [$SchemaName].[$baseTableName] WHERE [Name] = '$($dataSet.Tables[0].Rows[0].Name)';" | Enter-DbTransaction -PassThru
            }
            $dbData | Get-DbData
            # Add
            $dbData | New-DbBulkCopy -DataSet $DataSet -Timeout 600
            $dbData | Exit-DbTransaction -Commit
        } catch {
            if ($dbData) {
                $dbData | Exit-DbTransaction -Rollback
            }
            throw
        }
    }
}
