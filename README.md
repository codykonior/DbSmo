# PowerShell: DbSmo Module

## TOPIC
    about_DbSmo

## SHORT DESCRIPTION

## LONG DESCRIPTION

## REQUIREMENTS
    Destination database needs the destination schema (Smo) to exist,
    and for the below stored procedure:

Create Procedure dbo.DeleteTemporal
    @SchemaName Sysname,
    @TableName Sysname,
    @Name Sysname
As
Begin
    Declare @Tables Table (
        Level Int,
        SchemaName Sysname,
        TableName Sysname,
        ColumnName Sysname
        )

    Declare @ColumnName Sysname
    Declare @Sql Nvarchar(1000)

    ; With Cte As (
        Select  1 As level,
                t.schema_id,
                t.object_id,
                Cast('Name' As Sysname) As column_name
        From    sys.tables t
        Where   t.schema_id = Schema_Id(@SchemaName)
        And     t.name = @TableName
        Union   All
        Select  level + 1,
                t.schema_id,
                t.object_id,
                Cast(@TableName + 'Name' As Sysname) As column_name
        From    Cte c
        Join    sys.foreign_keys fk
        On      c.object_id = fk.referenced_object_id
        Join    sys.tables t
        On      fk.schema_id = t.schema_id
        And     fk.parent_object_id = t.object_id
        Where   fk.delete_referential_action_desc = 'CASCADE'
        )
    Insert  @Tables
    Select  level As Level,
            Quotename(Schema_Name(schema_id)),
            Quotename(Object_Name(object_id)),
            Quotename(column_name) As Column_Name
    From    Cte c

    Declare CTE_Delete_Temporal Cursor Local Forward_Only Read_Only Static For
            Select  SchemaName,
                    TableName,
                    ColumnName
            From    @Tables
            Order By Level Desc

    Open    CTE_Delete_Temporal
    Fetch   Next From CTE_Delete_Temporal Into @SchemaName, @TableName, @ColumnName

    While   @@Fetch_Status = 0
    Begin
            Set     @Sql = 'Delete From ' + @SchemaName + '.' + @TableName + ' Where ' + @ColumnName + ' = @Name'
            Exec    sp_executesql @Sql, N'@Name Sysname', @Name

            Fetch   Next From CTE_Delete_Temporal Into @SchemaName, @TableName, @ColumnName
    End

    Close   CTE_Delete_Temporal
    Deallocate CTE_Delete_Temporal
End
Go

	
## EXAMPLE #1

## LINKS


