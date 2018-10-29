<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-DbWmi {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $ComputerName,

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

            $object = Get-DbWmi $ComputerName
            $dataSet = ConvertFrom-DbSmo $object
            "($ComputerName Schema)" | Add-PerformanceRecord $performanceTotal
            Write-DbSmoData $dataSet $DestinationServerInstance $DestinationDatabaseName $DestinationSchemaName
            "($ComputerName)" | Add-PerformanceRecord $performanceTotal

            Get-PerformanceRecord | Sort-Object Value -Descending | ForEach-Object {
                Write-Output "Performance $($_.Name) = $($_.Value)"
            }
        }
    }

    end {
        Publish-Jojoba
    }
}
