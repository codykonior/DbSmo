<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-DbSmo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias("Name")]
        [string] $InputObject,
        [string] $ServerInstance,
        [string] $Database,

        [switch] $Smo,
        [switch] $Wmi,

        [string] $JojobaBatch = [System.Guid]::NewGuid().ToString(),
        [switch] $JojobaJenkins,
        [int]    $JojobaThrottle = $env:NUMBER_OF_PROCESSORS
    )

    begin {
    }

    process {
        Start-Jojoba {
            if (!$Smo -and !$Wmi) {
                throw "Neither the -Smo or -Wmi switches were used and one must be used"
            }

            Clear-PerformanceRecord
            $performanceTotal = Get-Date
            Write-Verbose "Started $InputObject"

            $schemaName = "Smo"

            if ($Smo) {    
                $object = Get-DbSmo $InputObject -Preload
            } elseif ($Wmi) {
                $object = Get-DbWmi $InputObject
            }

            $performanceSchema = Get-Date
            $dataSet = ConvertFrom-DbSmo $object

            try {
                $dataSet.EnforceConstraints = $true
            } catch {
                $failures = $dataSet.Tables | ForEach { 
                    if ($_.GetErrors()) { 
                        "Table: $($_.TableName)"
                        "Errors:"
                        $_.GetErrors()
                    }
                } | Out-String

                throw "Enforcing constraints failed. What follows are the tables and rows involved: $failures"
            }

            New-DbSmoSchema $dataSet -ServerInstance $ServerInstance -Database $Database -SchemaName $schemaName 

            $dbData = New-DbConnection -ServerInstance $ServerInstance -Database $Database | New-DbCommand "Exec dbo.DeleteTemporal @SchemaName = @SchemaName, @TableName = @TableName, @ColumnName = 'Name', @Value = @Value" -Parameters @{ SchemaName = $schemaName; TableName = $dataSet.Tables[0].TableName; Value = $object.Name; } | Enter-DbTransaction -TransactionName $InputObject.Substring(0, [Math]::Min($InputObject.Length, 32)) -PassThru

            # To bulk copy we need proper schema and table names
            $dataSet.Tables | ForEach {
                $_.TableName = "[$schemaName].[$($_.TableName)]"
            }
            
            # Delete
            try {
                $dbData | Get-DbData -NoCommandBuilder 
                $dbData | New-DbBulkCopy -DataSet $dataSet -Timeout 600
                $dbData | Exit-DbTransaction -Commit
            } catch {
                $dbData | Exit-DbTransaction -Rollback
                throw
            }
            
            $endDate = Get-Date
            Write-Verbose "Finished $InputObject at $endDate"
            "($InputObject Schema $schemaName)" | Add-PerformanceRecord $performanceSchema
            "($InputObject Total)" | Add-PerformanceRecord $performanceTotal

            Get-PerformanceRecord | Sort Value -Descending | ForEach { 
                Write-Output "Performance $($_.Name) = $($_.Value)" 
            } 
        }
    }
    
    end {
        Publish-Jojoba
    }
}
