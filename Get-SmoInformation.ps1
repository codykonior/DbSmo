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
        [Parameter(Mandatory = $true, ParameterSetName = "Smo", Position = 1)]
        [Parameter(Mandatory = $true, ParameterSetName = "Wmi", Position = 1)]
        [string] $ServerInstance,

        [Parameter(Mandatory = $true, ParameterSetName = "Smo", Position = 2)]
        [Parameter(Mandatory = $true, ParameterSetName = "Wmi", Position = 2)]
        [string] $SaveServerInstance,
        [Parameter(Mandatory = $true, ParameterSetName = "Smo", Position = 3)]
        [Parameter(Mandatory = $true, ParameterSetName = "Wmi", Position = 3)]
        [string] $SaveDatabase,

        [Parameter(Mandatory = $false, ParameterSetName = "Smo", Position = 4)]
        [Parameter(Mandatory = $false, ParameterSetName = "Wmi", Position = 4)]
        $SchemaName,

        [Parameter(Mandatory = $true, ParameterSetName = "Smo")]
        [switch] $Smo,
        [Parameter(Mandatory = $true, ParameterSetName = "Wmi")]
        [switch] $Wmi
    )

    $performance = @{}
    Write-Verbose "Started $ServerInstance"

    if ($Smo) {
        $object = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerInstance)
        if (!$SchemaName) {
            $SchemaName = "smo"
        }
    } elseif ($Wmi) {
        $object = New-Object Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer($ServerInstance)
        if (!$SchemaName) {
            $SchemaName = "wmi"
        }
    }

    $performanceSchema = Get-Date

    $dataSet = ConvertFrom-Smo $object

    try {
        $dataSet.EnforceConstraints = $true
    } catch {
        Write-Error "Enforcing constraints failed. What follows are the tables and rows involved:" -ErrorAction:Continue
            
        $dataSet.Tables | %{ 
            if ($_.GetErrors()) { 
                $_.TableName
                $_.GetErrors()
            }
        }
    
        Write-Error "Exception: $_"
    }

    Add-SmoDatabaseSchema $dataSet $SaveServerInstance $SaveDatabase $SchemaName 

    $bulkCopyConnection = New-Object System.Data.SqlClient.SqlConnection("Server=$SaveServerInstance;Database=$SaveDatabase;Trusted_Connection=true")
    $bulkCopyConnection.Open()
    $bulkCopyTransaction = $bulkCopyConnection.BeginTransaction($ServerInstance.Substring(0, [Math]::Min($ServerInstance.Length, 32)))
        
    try {
        $deleteCommand = $bulkCopyConnection.CreateCommand()
        $deleteCommand.Transaction = $bulkCopyTransaction

        <# 
        if ($Smo) { 
            $deleteCommand.CommandText = "Delete From $(Encode-SqlName $SchemaName).[Server] Where Name = @Name"
        } elseif ($Wmi) {
            $deleteCommand.CommandText = "Delete From $(Encode-SqlName $SchemaName).[ManagedComputer] Where Name = @Name"
        }
        $deleteParameter = $deleteCommand.CreateParameter()
        $deleteParameter.ParameterName = "Name"
        $deleteParameter.Value = $object.Name
        [void] $deleteCommand.Parameters.Add($deleteParameter)
        #>

        # Temporal cascade deletes are broken so we need a workaround
        $deleteCommand.CommandText = "Exec dbo.DeleteTemporal @SchemaName = @SchemaName, @TableName = @TableName, @Name = @Name"
        $deleteParameter = $deleteCommand.CreateParameter()
        $deleteParameter.ParameterName = "SchemaName"
        $deleteParameter.Value = $SchemaName
        [void] $deleteCommand.Parameters.Add($deleteParameter)
        $deleteParameter = $deleteCommand.CreateParameter()
        $deleteParameter.ParameterName = "TableName"
        $deleteParameter.Value = $dataSet.Tables[0].TableName
        [void] $deleteCommand.Parameters.Add($deleteParameter)
        $deleteParameter = $deleteCommand.CreateParameter()
        $deleteParameter.ParameterName = "Name"
        $deleteParameter.Value = $object.Name
        [void] $deleteCommand.Parameters.Add($deleteParameter)

        Write-Verbose "Deleting existing entry for $($object.Name)"
        [void] $deleteCommand.ExecuteNonQuery()

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($bulkCopyConnection, [System.Data.SqlClient.SqlBulkCopyOptions]::Default, $bulkCopyTransaction)

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
    "($ServerInstance Schema $schemaName)" | Add-PerformanceRecord $performanceSchema

    Get-PerformanceRecord | Sort Value -Descending | Out-String | Write-Verbose
}
