
SET NOCOUNT ON;


DECLARE @work_table TABLE (
RowID BIGINT
);

---
WHILE ((SELECT COUNT(1) FROM logTempDbGrowthByQuery WHERE CAST(RowCreationDate AS DATE) < CAST(GETDATE() - 60 AS DATE)) > 0)
BEGIN

	INSERT INTO @work_table (
		RowID
	)
	SELECT TOP 10000
	RowId
	FROM logTempDbGrowthByQuery
	WHERE CAST(RowCreationDate AS DATE) < CAST(GETDATE() - 60 AS DATE)
	ORDER BY RowCreationDate
	;
	
	DELETE logTempDbGrowthByQuery
	FROM logTempDbGrowthByQuery
	JOIN @work_table AS work_table
		ON logTempDbGrowthByQuery.RowId = work_table.RowID
	;
	
	DELETE FROM @work_table;
	
	--DBCC SHRINKFILE (N'NexidiaPerformance_Log' , 0);

END
