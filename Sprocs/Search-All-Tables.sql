

CREATE PROC SearchAllTables (
	@SearchStr NVARCHAR(1000)
)
AS

BEGIN

SET NOCOUNT ON;

--Store the results:
CREATE TABLE #Results (ColumnName NVARCHAR(370), ColumnValue NVARCHAR(MAX))

--vars
DECLARE @TableName NVARCHAR(255), @ColumnName NVARCHAR(255), @quoted_search NVARCHAR(1024)

--initialize
SET  @TableName = ''
SET @quoted_search = QUOTENAME('%' + @SearchStr + '%','''')

--loop tables:
WHILE @TableName IS NOT NULL
BEGIN
    SET @ColumnName = ''
    SET @TableName = 
    (
        SELECT MIN(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME))
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
        AND QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME) > @TableName
        AND OBJECTPROPERTY(OBJECT_ID(QUOTENAME(TABLE_SCHEMA) + '.' + QUOTENAME(TABLE_NAME)), 'IsMSShipped') = 0
    )

	--Loop columns:
    WHILE (@TableName IS NOT NULL) AND (@ColumnName IS NOT NULL)
    BEGIN
        SET @ColumnName =
        (
            SELECT MIN(QUOTENAME(COLUMN_NAME))
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = PARSENAME(@TableName, 2)
            AND TABLE_NAME = PARSENAME(@TableName, 1)
            AND DATA_TYPE IN ('CHAR', 'VARCHAR', 'NCHAR', 'NVARCHAR')
            AND QUOTENAME(COLUMN_NAME) > @ColumnName
        )

        IF @ColumnName IS NOT NULL
        BEGIN
            INSERT INTO #Results
            EXEC
            (
                'SELECT ''' + @TableName + '.' + @ColumnName + ''', LEFT(' + @ColumnName + ', 3630) 
                FROM ' + @TableName + ' WITH (NOLOCK) ' +
                ' WHERE ' + @ColumnName + ' LIKE ' + @quoted_search
            )
        END

    END --loop columns
END --loop tables

SELECT ColumnName, ColumnValue FROM #Results

END