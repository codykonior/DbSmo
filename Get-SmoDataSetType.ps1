<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Get-SmoDataSetType {
    [CmdletBinding()]    
    param (
        $TypeName
    )

    $performanceDataSetType = Get-Date

    if ($SmoDataSetSimpleTypes -contains $TypeName) {
        $TypeName
    } elseif ($SmoDataSetStringTypes -contains $TypeName -or ([type] $TypeName).IsEnum) {
        "System.String"
    }
    # The IsEnum check is for types like $smo.Databases[0].UserAccess / Microsoft.SqlServer.Management.Smo.DatabaseUserAccess

    "(GetDataSetType)" | Add-PerformanceRecord $performanceDataSetType
} 
