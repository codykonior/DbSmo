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
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $ServerInstance,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationServerInstance,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationDatabaseName,

        [ValidateNotNullOrEmpty()]
        [string] $DestinationSchemaName = "Smo",

        [Parameter(ValueFromRemainingArguments)]
        $Jojoba
    )

    begin {
    }

    process {
        Start-Jojoba {
            Clear-PerformanceRecord
            $performanceTotal = Get-Date

            $object = Get-DbSmo $ServerInstance -Preload
            $dataSet = ConvertFrom-DbSmo $object
            "($ServerInstance Schema)" | Add-PerformanceRecord $performanceTotal
            Write-DbSmoData $dataSet $DestinationServerInstance $DestinationDatabaseName $DestinationSchemaName
            "($ServerInstance)" | Add-PerformanceRecord $performanceTotal

            Get-PerformanceRecord | Sort-Object Value -Descending | ForEach-Object { 
                Write-Output "Performance $($_.Name) = $($_.Value)" 
            }     
        }
    }
    
    end {
        Publish-Jojoba
    }
}
