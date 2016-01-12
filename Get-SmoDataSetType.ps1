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
        "System.String",
        "System.Timespan",
        "System.Version"
    )

    if ($typeList -contains $TypeName) {
        $TypeName
    } elseif ($stringList -contains $TypeName -or (& ([ScriptBlock]::Create("[$TypeName].BaseType -eq [System.Enum]")))) {
        "System.String"
    } else {
        $null
    }
}
