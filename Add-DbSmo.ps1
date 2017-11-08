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
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("ServerInstance")]
        [string] $InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationServerInstance,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DestinationDatabaseName,

        [ValidateNotNullOrEmpty()]
        [string] $DestinationSchemaName = "Smo",

        [string] $JojobaBatch = [System.Guid]::NewGuid().ToString(),
        [switch] $JojobaJenkins,
        [int]    $JojobaThrottle = $env:NUMBER_OF_PROCESSORS
    )

    begin {
    }

    process {
        Start-Jojoba {
            Clear-PerformanceRecord
            $performanceTotal = Get-Date

            $object = Get-DbSmo $InputObject -Preload
            $dataSet = ConvertFrom-DbSmo $object
            "($InputObject Schema)" | Add-PerformanceRecord $performanceTotal
            Write-DbSmoData $dataSet $DestinationServerInstance $DestinationDatabaseName $DestinationSchemaName
            "($InputObject)" | Add-PerformanceRecord $performanceTotal

            Get-PerformanceRecord | Sort-Object Value -Descending | ForEach-Object { 
                Write-Output "Performance $($_.Name) = $($_.Value)" 
            }     
        }
    }
    
    end {
        Publish-Jojoba
    }
}
