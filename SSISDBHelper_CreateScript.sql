EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'SSISDBHelper'
GO
use [SSISDBHelper];
GO
use [master];
GO
USE [master]
GO
ALTER DATABASE [SSISDBHelper] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE [master]
GO
/****** Object:  Database [SSISDBHelper]    Script Date: 4/5/2020 6:38:53 PM ******/
DROP DATABASE [SSISDBHelper]
GO
CREATE DATABASE [SSISDBHelper]
GO
USE SSISDBHelper
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE SCHEMA Scheduler
GO
CREATE OR ALTER PROCEDURE Scheduler.Job$CleanupOldCopies
(
	@KeepGenerationCount int = 2,
	@DeleteActiveJobsFlag bit = 0
)
AS
SET NOCOUNT ON;
WITH BaseRows AS(
SELECT REVERSE(SUBSTRING(REVERSE(name),20,200)) AS baseName, name
FROM msdb.dbo.sysjobs
WHERE name LIKE '%z_old_%(Managed)%'
),Generations AS(
SELECT *, ROW_NUMBER() OVER (PARTITION BY baseName ORDER BY name ASC) AS GenerationNumber
FROM BaseRows
)
SELECT 'exec msdb.dbo.sp_delete_job @job_name = ''' + Name + '''' AS Name, Generations.GenerationNumber
INTO #holdToDelete
FROM  Generations
WHERE GenerationNumber > @KeepGenerationCount
UNION 
SELECT 'exec msdb.dbo.sp_delete_job @job_name = ''' + Name + '''', NULL AS GenerationsNUmber
FROM msdb.dbo.sysjobs
WHERE  name LIKE '%(Managed)%'
  AND @deleteActiveJobsFlag = 1

DECLARE @cursor CURSOR, @stmt nvarchar(MAX)
SET @cursor = CURSOR FOR (SELECT name FROM #holdToDelete)
OPEN @cursor
WHILE 1=1
 BEGIN
	FETCH NEXT FROM @cursor INTO @stmt
	IF @@FETCH_STATUS <> 0
	    BREAK
	PRINT @stmt
	EXEC (@stmt)
 END

GO








/******************
Test Objects
*******************/
GO
CREATE SCHEMA Test;
GO
CREATE TABLE Test.TestJobs
(
	TestJobsId	 int Identity NOT NULL CONSTRAINT PKTestTable PRIMARY KEY,
	SystemName   nvarchar(100) NOT NULL,
	RowCreatedTime datetime2(0) NOT NULL CONSTRAINT DFLTTestTable$RowCreatedTime DEFAULT (SYSDATETIME())
) WITH (DATA_COMPRESSION = PAGE);