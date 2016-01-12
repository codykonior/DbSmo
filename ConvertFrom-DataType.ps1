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
        [Parameter(Mandatory = $true)]
        [string] $TypeName
    )

    switch ($TypeName) {  
        "Boolean" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Bit
        }  
        "Byte[]" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::VarBinary
        }
        "Byte"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::TinyInt
        }  
        "DateTime"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::DateTime2
        }     
        "Decimal" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal
        }  
        "Double" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Float
        }  
        "Guid" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::UniqueIdentifier
        }  
        "Int16"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt
        }  
        "Int32"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Int
        }  
        "Int64" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt
        }  
        "UInt16"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::SmallInt
        }  
        "UInt32"  {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Int
        }  
        "UInt64" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::BigInt
        }  
        "Single" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::Decimal
        }
        "String" {
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::VarChar
        }
        default {
            # This basically defaults everything else so that if we passed something we really
            # didn't expect then we won't be storing a raw object; it'll be cast to string.
            [Microsoft.SqlServer.Management.Smo.SqlDataType]::VarChar
        }  
    }  
}
