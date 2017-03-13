
SELECT
TableName = sys.schemas.name + '.' + sys.objects.name
,IndexName = sys.indexes.name
,IndexID = sys.indexes.index_id
,IndexScore = (dm_ius.user_seeks + dm_ius.user_scans + dm_ius.user_lookups)
,UserSeeks = dm_ius.user_seeks
--,SystemSeeks = dm_ius.system_seeks
,LastSeek = dm_ius.last_user_seek
,UserScans = dm_ius.user_scans
--,SystemScans = dm_ius.system_scans
,LastScan = dm_ius.last_user_scan
,UserLookups = dm_ius.user_lookups
--,SystemLookups = dm_ius.system_lookups
,LastLookup = dm_ius.last_user_lookup
,UserUpdates = dm_ius.user_updates
--,SystemUpdates = dm_ius.system_updates
,LastUpdate = dm_ius.last_user_update
,TableRows = partition_info.TableRows
,IndexSizeKB = indexspaceused.IndexSizeKB
,IndexSizeMB = indexspaceused.IndexSizeMB
,IndexSizeGB = indexspaceused.IndexSizeGB
,Drop_Statement =  'DROP INDEX ' + QUOTENAME(sys.indexes.name)
				+ ' ON ' + QUOTENAME(sys.schemas.name) + '.'
				+ QUOTENAME(OBJECT_NAME(dm_ius.OBJECT_ID))
FROM sys.dm_db_index_usage_stats AS dm_ius
JOIN sys.indexes
	ON sys.indexes.index_id = dm_ius.index_id 
	AND dm_ius.OBJECT_ID = sys.indexes.OBJECT_ID
JOIN sys.objects
	ON dm_ius.OBJECT_ID = sys.objects.OBJECT_ID
JOIN sys.schemas
	ON sys.objects.schema_id = sys.schemas.schema_id
JOIN (
	SELECT 
	SUM(sys.partitions.rows) TableRows
	, sys.partitions.index_id
	, sys.partitions.OBJECT_ID
	FROM sys.partitions
	GROUP BY sys.partitions.index_id, sys.partitions.OBJECT_ID
		)  AS partition_info
ON partition_info.index_id = dm_ius.index_id 
AND dm_ius.OBJECT_ID = partition_info.OBJECT_ID

JOIN (
	SELECT 
	sys.indexes.[name] AS IndexName
	,SUM(indexStats.[used_page_count]) * 8 AS IndexSizeKB
	,(SUM(indexStats.[used_page_count]) * 8) / 1024 AS IndexSizeMB
	,((SUM(indexStats.[used_page_count]) * 8) / 1024) /1024 AS IndexSizeGB
	FROM sys.dm_db_partition_stats AS indexStats
	JOIN sys.indexes
		ON indexStats.[object_id] = sys.indexes.[object_id]
		AND indexStats.[index_id] = sys.indexes.[index_id]
	GROUP BY sys.indexes.[name]
	) AS indexspaceused
ON sys.indexes.name = indexspaceused.IndexName

WHERE OBJECTPROPERTY(dm_ius.OBJECT_ID,'IsUserTable') = 1
AND dm_ius.database_id = DB_ID()
AND sys.indexes.is_primary_key = 0
AND sys.indexes.is_unique_constraint = 0
--filter out clustered indexes:
AND sys.indexes.type <> 1 

ORDER BY IndexScore ASC
;
