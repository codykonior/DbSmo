function Get-SmoDataSetType {
    [CmdletBinding()]    
    param (
        $TypeName
    )

    $typeList = @(
        "System.Boolean",
        "System.Byte",
        "System.Byte[]",
        "System.Char",
        "System.DateTime",
        "System.Decimal",
        "System.Double",
        "System.Guid",
        "System.Int16",
        "System.Int32",
        "System.Int64",
        "System.Single",
        "System.UInt16",
        "System.UInt32",
        "System.UInt64"
        )
    
    $stringList = @(
        "System.Enum",
        "ScriptProperty", # Used on IPAddressToString
        "System.String",
        "System.Timespan",
        "System.Version"
    )

    if ($typeList -contains $TypeName) {
        $TypeName
    } elseif ($stringList -contains $TypeName -or (& ([ScriptBlock]::Create("[$TypeName].BaseType -eq [System.Enum]")))) { # There's also a type .IsEnum; used on lots of Server.* stuff, only on the GetType()
        "System.String"
    } else {
        $null
    }
} 
