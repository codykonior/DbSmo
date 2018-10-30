<#

.SYNOPSIS

.DESCRIPTION

.PARAMETER

.INPUTS

.OUTPUTS

.EXAMPLE

#>

function Add-DbDeleteTemporalProcedure {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $ServerInstance,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $DatabaseName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^[a-zA-Z0-9]+$')]
        [string] $SchemaName
    )

    begin {
    }

    process {
        $query = "Select * From sys.procedures Where Schema_Name(schema_id) = 'dbo' And name = 'DeleteTemporal';"
        $dbData = New-DbConnection $ServerInstance $DatabaseName | New-DbCommand $query | Get-DbData

        if (!$dbData) {
            $query = @'
Create Procedure [dbo].[DeleteTemporal]
    @SchemaName Sysname,
    @TableName Sysname,
    @ColumnName Sysname,
    @Value Sysname
As
Begin
    Set Nocount On;

    Declare @Tables Table (
        Level Int,
        SchemaName Sysname,
        TableName Sysname,
        ColumnName Sysname
        );

    Declare @Sql Nvarchar(Max) = '';
    Declare @SqlLine Nvarchar(Max) = '';

    ; With Cte As (
        Select  1 As level,
                s.name As SchemaName,
                t.name As TableName,
                c.name As ColumnName
        From    sys.tables t
        Join    sys.schemas s
        On      t.schema_id = s.schema_id
        Join    sys.columns c
        On      t.object_id = c.object_id
        Where   s.name = @SchemaName
        And     t.name = @TableName
        And         c.name = @ColumnName
        Union   All
        Select  level + 1,
                Schema_Name(t.schema_id),
                t.name,
                c2.name
        From    Cte
        Join    sys.columns c
        On      Object_Id(Quotename(Cte.SchemaName) + '.' + Quotename(Cte.TableName)) = c.object_id
        And         Cte.ColumnName = c.name
        Join    sys.foreign_key_columns fkc
        On      c.object_id = fkc.referenced_object_id
        And         c.column_id = fkc.referenced_column_id
        Join    sys.tables t
        On      fkc.parent_object_id = t.object_id
        Join    sys.columns c2
        On      fkc.parent_object_id = c2.object_id
        And         fkc.parent_column_id = c2.column_id
        -- Where   fk.delete_referential_action_desc = 'CASCADE'
        )
    Insert  @Tables
    Select  level As Level,
            Quotename(SchemaName) As SchemaName,
            Quotename(TableName) As TableName,
            Quotename(ColumnName) As ColumnName
    From    Cte c;

    Declare CTE_Delete_Temporal Cursor Local Forward_Only Read_Only Static For
            Select  SchemaName,
                    TableName,
                    ColumnName
            From    @Tables
            Order By Level Desc;

    Open    CTE_Delete_Temporal;
    Fetch   Next From CTE_Delete_Temporal Into @SchemaName, @TableName, @ColumnName;

    While   @@Fetch_Status = 0
    Begin
            Set     @SqlLine = 'Delete From ' + @SchemaName + '.' + @TableName + ' Where ' + @ColumnName + ' = @Value;
'
            Print   @SqlLine;
            Set     @Sql += @SqlLine;
            Fetch   Next From CTE_Delete_Temporal Into @SchemaName, @TableName, @ColumnName;
    End;

    Close   CTE_Delete_Temporal;
    Deallocate CTE_Delete_Temporal;

    Exec    sp_executesql @Sql, N'@Value Sysname', @Value;
End;
'@

            Write-Verbose "Creating dbo.DeleteTemporal stored procedure"
            New-DbConnection $ServerInstance $DatabaseName | New-DbCommand $query | Get-DbData -OutputAs NonQuery | Out-Null
        }

        $query = "Select * From sys.schemas Where name = @SchemaName;"
        $dbData = New-DbConnection $ServerInstance $DatabaseName | New-DbCommand $query -Parameters @{ SchemaName = $SchemaName; } | Get-DbData

        if (!$dbData) {
            # Can't create the schema from a variable unfortunately, so we did some regex
            # to restrict it to numbers and letters
            $query = "Create Schema [$SchemaName];"
            Write-Verbose "Creating schema $SchemaName"
            New-DbConnection $ServerInstance $DatabaseName | New-DbCommand $query | Get-DbData -OutputAs NonQuery | Out-Null

        }
    }

    end {
    }
}
