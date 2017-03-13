
-------------------------------------------------
--Rebuild or Reorganize Indexes
--Author: Dan Anderson
-------------------------------------------------
/*

@fill_factor = the fill factor to use when rebuilding indexes.

@nonclustered_frag_percent = the minimum fragmentation percentage for a non-clustered index to be included
							 in the result set.

@clustered_frag_percent = the minimum fragmentation percentage for a clustered index to be included
				          in the result set.

@rebuild_cutoff = the percent of fragmentation used to determine when to rebuild
				  vs. reorganize.

@index_pages = the minimum number a pages an index occupies for rebuild/reorganize consideration.

@time_cutoff = the maximum number of hours the script should execute. Note, this will stop any
			   further operations, however the current rebuild/reorganize will continue.

*/

--Options for tuning script:
DECLARE @fill_factor INT = 95; --anything > 70 and <= 95 is ideal.
DECLARE @nonclustered_frag_percent DECIMAL = 20.00; --good starting range = 20.00
DECLARE @clustered_frag_percent DECIMAL = 60.00; --good starting range >= 60.00
DECLARE @rebuild_cutoff DECIMAL = 40.00; --anything >= 35.00 should be rebuilt instead of reorganized.
DECLARE @index_pages INT = 1000; --index fragmentation below 1000 pages doesn't really matter.
DECLARE @time_cutoff INT = 3; --number of hours to run before stopping.


---------------------------------------
--Internal variables:
---------------------------------------

--work table
DECLARE @sql_statement NVARCHAR(MAX);
DECLARE @suspect_indexes TABLE (
	row_id INT IDENTITY(1,1)
	,database_name NVARCHAR(256)
	,schemaname NVARCHAR(256)
	,table_name NVARCHAR(256)
	,index_name NVARCHAR(256)
	,index_type NVARCHAR(256)
	,pages_used INT
	,index_size_mb DECIMAL (18,2)
	,fragmentation DECIMAL (18,2)
	,sql_statement NVARCHAR(MAX)
);


---------------------------------------
--Create the table of indexes to work on:
---------------------------------------

SET NOCOUNT ON;


INSERT INTO @suspect_indexes (
database_name
,schemaname
,table_name
,index_name
,index_type
,pages_used
,index_size_mb
,fragmentation
,sql_statement
)
SELECT DISTINCT
database_name = DB_NAME(DB_ID())
,schemaname = sys.schemas.[name]
,table_name = sys.tables.[name]
,index_name = sys.indexes.[name]
,index_type = phys_stats.index_type_desc
,pages_used = phys_stats.page_count
,index_size_mb = (phys_stats.page_count * 8) / 1024
,fragmentation = phys_stats.avg_fragmentation_in_percent
,sql_statement = CASE
					WHEN phys_stats.avg_fragmentation_in_percent >= @rebuild_cutoff AND phys_stats.index_type_desc <> 'CLUSTERED INDEX' THEN 'ALTER INDEX ' + sys.indexes.[name] + ' ON ' + sys.schemas.[name] + '.' + sys.tables.[name] + ' REBUILD WITH (FILLFACTOR = ' + CAST(@fill_factor AS NVARCHAR(3)) + ');'
					WHEN phys_stats.avg_fragmentation_in_percent >= @rebuild_cutoff AND phys_stats.index_type_desc = 'CLUSTERED INDEX' THEN 'ALTER INDEX ' + sys.indexes.[name] + ' ON ' + sys.schemas.[name] + '.' + sys.tables.[name] + ' REBUILD WITH (FILLFACTOR = 100);'
					ELSE 'ALTER INDEX ' + sys.indexes.[name] + ' ON ' + sys.schemas.[name] + '.' + sys.tables.[name] + ' REORGANIZE;'
				 END
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS phys_stats
LEFT JOIN sys.tables
	ON phys_stats.[object_id] = sys.tables.[object_id]
LEFT JOIN sys.schemas 
	ON sys.tables.[schema_id] = sys.schemas.[schema_id]
LEFT JOIN sys.indexes 
	ON phys_stats.[object_id] = sys.indexes.[object_id]
	AND phys_stats.[index_id] = sys.indexes.[index_id]
WHERE sys.schemas.[name] IS NOT NULL
AND sys.tables.[name] IS NOT NULL
AND phys_stats.page_count >= @index_pages
AND ( 
	(phys_stats.avg_fragmentation_in_percent >= @nonclustered_frag_percent AND phys_stats.index_type_desc = 'NONCLUSTERED INDEX')
	OR 
	(phys_stats.avg_fragmentation_in_percent >= @clustered_frag_percent AND phys_stats.index_type_desc = 'CLUSTERED INDEX')
	)
;


---------------------------------------
--Control Variables:
---------------------------------------

DECLARE @start_time DATETIME = GETDATE();
DECLARE @exit_time DATETIME = DATEADD(hh,@time_cutoff,@start_time);
DECLARE @total_rows INT;
DECLARE @row_id INT;


--Debug the work table:
--SELECT * FROM @suspect_indexes ORDER BY pages_used

---------------------------------------
--Start performing the work:
---------------------------------------

SET @total_rows = (SELECT COUNT(1) FROM @suspect_indexes);

--Loop:
WHILE (@total_rows > 0) 
BEGIN

	--Check for the time cutoff:
	IF (GETDATE() >= @exit_time)
		BEGIN
			BREAK;
		END
	ELSE
		BEGIN

			--Set the current value to work on:
			SET @row_id = (SELECT TOP 1 row_id FROM @suspect_indexes ORDER BY pages_used);
			SET @sql_statement = (SELECT sql_statement FROM @suspect_indexes WHERE row_id = @row_id);

			--Execute the statement:
			--PRINT @sql_statement;
			EXEC (@sql_statement);

			--Setup new work item:
			DELETE FROM @suspect_indexes WHERE row_id = @row_id;
			SET @total_rows = (SELECT COUNT(1) FROM @suspect_indexes);

		END --end time check

END --end while
;
