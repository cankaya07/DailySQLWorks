IF OBJECT_ID('dbo.FilegroupFreeSpace') IS NULL
  EXEC ('CREATE PROCEDURE dbo.FilegroupFreeSpace AS RETURN 0;');
GO
print 'You can check your Filegroup''s free size easily. Up to date scripts code -> https://github.com/cankaya07/DailySQLWorks 
I shared some code sample with my approach

Sample 0:
exec dbo.FilegroupFreeSpace 10 under 10 percent free space filegroups will be logged your errorlog 

Sample 1:
exec dbo.FilegroupFreeSpace 10,1 under 10 percent free space filegroups will be logged your errorlog and show resultset


#######
basically script calculates all filegroups total size and free per database even calculate percentage :) 
after that write some log records to errorlog related with your db and your threashold. 
I prefer to you execute script daily for example 10pm and use sql agent alert and notification..
#####

--Add message
USE [master]
GO
EXEC sp_addmessage @msgnum = 75006, @severity = 1,   
   @msgtext = N''"%s" Filegroup has %s percent free space in %s.'',   
   @lang = ''us_english'';  

--Add alert 
USE [msdb]
GO
EXEC msdb.dbo.sp_add_alert @name=N''File_Group_Free_Space_Percent'', 
		@message_id=75006, 
		@severity=0, 
		@enabled=1, 
		@delay_between_responses=0, 
		@include_event_description_in=1

--add notification
EXEC msdb.dbo.sp_add_notification @alert_name=N''File_Group_Free_Space_Percent'', @operator_name=N''YOUR_OPERATORNAME'', @notification_method = 7

--add job daily at 10 pm
exec dbo.FilegroupFreeSpace
GO
'
GO
ALTER PROCEDURE dbo.FilegroupFreeSpace(
@Threashold int = 10,
@ShowMe bit =0,
@WriteLog bit =1
)
AS
BEGIN
	--adding necessary message
	IF NOT EXISTS(select * from sys.sysmessages where error=75006)
	BEGIN
		EXEC sp_addmessage @msgnum = 75006, @severity = 1,   
		   @msgtext = N'"%s" Filegroup has %s percent free space in %s.',   
		   @lang = 'us_english';  
	END

IF OBJECT_ID('tempdb..#ALL_DB_Files') IS NOT NULL
  DROP TABLE #ALL_DB_Files; 

DECLARE @DbName nvarchar(200), @FreeSpacePercent decimal(18,2), @FileGroupName varchar(100), @PercentStr varchar(10);

CREATE TABLE #ALL_DB_Files (
dbname SYSNAME,
[FileGroupName] nvarchar(200),
[spaceused] BIGINT NOT NULL,
fileid smallint,
groupid smallint,
[size] BIGINT NOT NULL,
[maxsize] INT NOT NULL,
growth INT NOT NULL,
status INT,
perf INT,
[name] SYSNAME NOT NULL,
[filename] NVARCHAR(260) NOT NULL
)
EXEC sp_MsForEachDB 'use [?];Insert into #ALL_DB_Files select db_name(),b.groupname,FILEPROPERTY([name], ''spaceused'') as Spaceused,  a.* from sysfiles a INNER JOIN sys.sysfilegroups b ON a.groupid=b.groupid'
 

 IF (@ShowMe=1)
BEGIN
	select  
	dbname,
	FileGroupName,
	SUM(size)*CONVERT(FLOAT,8) / 1024.0 as totalsizeMB
	,SUM(spaceused)*CONVERT(FLOAT,8) / 1024.0 as usedsize
	,(SUM(size)-SUM(spaceused))/cast(SUM(size) as decimal(18,2))*100 as PercentFreePerByGroup
	,count(1) as FileCountInTheFileGroup
	from #ALL_DB_Files
	where dbname <>'tempdb'
	group by dbname,FileGroupName
	having ((SUM(size)-SUM(spaceused))/cast(SUM(size) as decimal(18,2))*100)<@Threashold
	order by 5





	SELECT  DISTINCT
	dovs.volume_mount_point AS Drive,
	CONVERT(INT,dovs.available_bytes/1048576.0) AS FreeSpaceInMB
	FROM sys.master_files mf
	CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) dovs
	ORDER BY 1 ASC
END



IF(@WriteLog=1)
BEGIN
	--loop through all rows
	WHILE EXISTS(SELECT NULL FROM #ALL_DB_Files 
									where dbname<>'tempdb' 
									group by dbname,FileGroupName
									having ((SUM(size)-SUM(spaceused))/cast(SUM(size) as decimal(18,2))*100)<@Threashold)
	BEGIN
	
		--work through each database
		SELECT TOP 1
			@DbName = dbname,
			@FreeSpacePercent = (SUM(size)-SUM(spaceused))/cast(SUM(size) as decimal(18,2))*100,
			@FileGroupName = FileGroupName
		FROM #ALL_DB_Files
			where dbname <>'tempdb'
			group by dbname,FileGroupName
			having ((SUM(size)-SUM(spaceused))/cast(SUM(size) as decimal(18,2))*100)<@Threashold

			set @PercentStr= cast(@FreeSpacePercent as varchar(10));

		--if we have databases that have reached our threshold, then we raise the alert
		RAISERROR  (75006, 10,1,@FileGroupName,@PercentStr,@DbName) WITH LOG;

		--remove the processed entry
		DELETE FROM #ALL_DB_Files WHERE dbname = @DbName;

	END
END

 
END





 