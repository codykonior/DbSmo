<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-PerformanceRecord {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $Name,
        [Parameter(Mandatory = $true, Position = 1)]
        [datetime] $Time
    )

    if (!(Test-Path Variable:Global:PerformanceRecord)) {
        $global:PerformanceRecord = @{}
    }

    if (!$global:PerformanceRecord.ContainsKey($Name)) {
        $global:PerformanceRecord.Add($Name, (Get-Date) - $Time)
    } else {
        $global:PerformanceRecord[$Name] += (Get-Date) - $Time
    }
}
