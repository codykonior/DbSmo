<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function ConvertFrom-DataType {
    [CmdletBinding()]    
    param (
        $TypeName
    )

    $performanceDataType = Get-Date

    if ($DataTypeSimple -contains $TypeName) {
        $TypeName
    } elseif ($DataTypeString -contains $TypeName -or ([type] $TypeName).IsEnum) {
        "System.String"
    }

    "(ConvertFrom-DataType)" | Add-PerformanceRecord $performanceDataType
} 
