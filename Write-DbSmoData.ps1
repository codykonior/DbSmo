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
        $dbData = New-DbConnection $ServerInstance $DatabaseName | New-DbCommand "Exec dbo.DeleteTemporal @SchemaName = @SchemaName, @TableName = @TableName, @ColumnName = 'Name', @Value = @Value" -Parameters @{ SchemaName = $SchemaName; TableName = $baseTableName; Value = $dataSet.Tables[0].Rows[0].Name; } | Enter-DbTransaction -TransactionName $InputObject.Substring(0, [Math]::Min($InputObject.Length, 32)) -PassThru

        # Delete
        try {
            $dbData | Get-DbData -NoCommandBuilder 
            $dbData | New-DbBulkCopy -DataSet $DataSet -Timeout 600
            $dbData | Exit-DbTransaction -Commit
        } catch {
            $dbData | Exit-DbTransaction -Rollback
            throw
        }
    }
}
