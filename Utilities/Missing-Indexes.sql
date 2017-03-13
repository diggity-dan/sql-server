

DECLARE @TableName NVARCHAR(256) = NULL;


SELECT
Database_ID = dm_mid.database_id
,Table_Name = OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) 
,Avg_Estimated_Impact = dm_migs.avg_user_impact*(dm_migs.user_seeks+dm_migs.user_scans)
,Last_User_Seek = dm_migs.last_user_seek
,Create_Statement = 'CREATE INDEX [IX_' + OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id) + '_'
					+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.equality_columns,''),', ','_'),'[',''),']','') 
					+ CASE
						WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN '_'
						ELSE ''
					  END
					+ REPLACE(REPLACE(REPLACE(ISNULL(dm_mid.inequality_columns,''),', ','_'),'[',''),']','')
					+ ']'
					+ ' ON ' + dm_mid.statement
					+ ' (' + ISNULL (dm_mid.equality_columns,'')
					+ CASE 
						WHEN dm_mid.equality_columns IS NOT NULL AND dm_mid.inequality_columns IS NOT NULL THEN ',' 
						ELSE '' 
					  END
					+ ISNULL (dm_mid.inequality_columns, '')
					+ ')'
					+ ISNULL (' INCLUDE (' + dm_mid.included_columns + ')', '')
FROM sys.dm_db_missing_index_groups dm_mig
JOIN sys.dm_db_missing_index_group_stats dm_migs
	ON dm_migs.group_handle = dm_mig.index_group_handle
JOIN sys.dm_db_missing_index_details dm_mid
	ON dm_mig.index_handle = dm_mid.index_handle
WHERE dm_mid.database_ID = DB_ID()
AND (
		@TableName IS NULL
		OR
		OBJECT_NAME(dm_mid.OBJECT_ID,dm_mid.database_id)  = @TableName
	)
ORDER BY Avg_Estimated_Impact DESC
;
