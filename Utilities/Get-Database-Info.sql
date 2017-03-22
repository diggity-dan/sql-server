SELECT 
database_name = sys.databases.name
,collation_name
,recovery_model_desc
,logical_file_name = sys.master_files.name
,sys.master_files.type_desc
,sys.master_files.physical_name
,growth = CASE
			WHEN sys.master_files.is_percent_growth = 0 THEN CAST(((sys.master_files.growth * 8) / 1024) AS NVARCHAR(20)) + ' MB'
			ELSE CAST(sys.master_files.growth AS NVARCHAR(10)) + '%'
		  END
,size_kb = (sys.master_files.size * 8)
,size_mb = CAST(((sys.master_files.size * 8) / 1024) AS DECIMAL(18,2))
,size_gb = CAST(((((sys.master_files.size * 8) / 1024)) / 1024) AS DECIMAL (18, 2))
,max_size = CASE
				WHEN sys.master_files.max_size = -1 THEN CAST('Unlimited' AS NVARCHAR(255))
				WHEN sys.master_files.max_size = 0 THEN CAST('None' AS NVARCHAR(255))
				ELSE CAST(((CAST(sys.master_files.max_size AS BIGINT) * 8) / 1024) AS NVARCHAR(100)) + ' MB'
			END
FROM sys.databases
JOIN sys.master_files
	ON sys.databases.database_id = sys.master_files.database_id
ORDER BY sys.databases.name
