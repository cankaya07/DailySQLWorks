--get LSN current database

DECLARE 
@DBName nvarchar(200)='AdventureWorks',
@AGName varchar(200)='XAVG', 
@ContinueWithDiff bit = 0,
@ContinueWithLog bit = 0,
@ContinueFullCopyOnly bit =1,
@HadrSET bit =1,
@BackupPath nvarchar(4000)='',

@HeadersSQL AS NVARCHAR(4000) = N'', --Dynamic insert into #Headers table (deals with varying results from RESTORE FILELISTONLY across different versions)
@sql NVARCHAR(MAX) = N'', --Holds executable SQL commands
@BackupFileFullPath nvarchar(4000) --holds absolute path of backup file


-- Get the SQL Server version number because the columns returned by RESTORE commands vary by version
-- Based on: https://www.brentozar.com/archive/2015/05/sql-server-version-detection/
-- Need to capture BuildVersion because RESTORE HEADERONLY changed with 2014 CU1, not RTM
DECLARE @ProductVersion AS NVARCHAR(20) = CAST(SERVERPROPERTY ('productversion') AS NVARCHAR(20));
DECLARE @MajorVersion AS SMALLINT = CAST(PARSENAME(@ProductVersion, 4) AS SMALLINT);
DECLARE @MinorVersion AS SMALLINT = CAST(PARSENAME(@ProductVersion, 3) AS SMALLINT);
DECLARE @BuildVersion AS SMALLINT = CAST(PARSENAME(@ProductVersion, 2) AS SMALLINT);

IF @MajorVersion < 10
BEGIN
  RAISERROR('Sorry, DatabaseRestore doesn''t work on versions of SQL prior to 2008.', 15, 1);
  RETURN;
END;

IF OBJECT_ID(N'tempdb..#FileList') IS NOT NULL DROP TABLE #FileList;
CREATE TABLE #FileList
(
    BackupFile NVARCHAR(255),
	depth int,
	[file] int,
	DbName nvarchar(200) null,
	BackupDate datetime null,
	BackupType varchar(20) null,
	BackupPath varchar(4000) null,
	FullBackupPath AS BackupPath+DbName+'\'+BackupType+'\'+BackupFile
);

IF OBJECT_ID(N'tempdb..#Headers') IS NOT NULL DROP TABLE #Headers;
CREATE TABLE #Headers
(
    BackupName NVARCHAR(256),
    BackupDescription NVARCHAR(256),
    BackupType NVARCHAR(256),
    ExpirationDate NVARCHAR(256),
    Compressed NVARCHAR(256),
    Position NVARCHAR(256),
    DeviceType NVARCHAR(256),
    UserName NVARCHAR(256),
    ServerName NVARCHAR(256),
    DatabaseName NVARCHAR(256),
    DatabaseVersion NVARCHAR(256),
    DatabaseCreationDate NVARCHAR(256),
    BackupSize NVARCHAR(256),
    FirstLSN NVARCHAR(256),
    LastLSN NVARCHAR(256),
    CheckpointLSN NVARCHAR(256),
    DatabaseBackupLSN NVARCHAR(256),
    BackupStartDate NVARCHAR(256),
    BackupFinishDate NVARCHAR(256),
    SortOrder NVARCHAR(256),
    CodePage NVARCHAR(256),
    UnicodeLocaleId NVARCHAR(256),
    UnicodeComparisonStyle NVARCHAR(256),
    CompatibilityLevel NVARCHAR(256),
    SoftwareVendorId NVARCHAR(256),
    SoftwareVersionMajor NVARCHAR(256),
    SoftwareVersionMinor NVARCHAR(256),
    SoftwareVersionBuild NVARCHAR(256),
    MachineName NVARCHAR(256),
    Flags NVARCHAR(256),
    BindingID NVARCHAR(256),
    RecoveryForkID NVARCHAR(256),
    Collation NVARCHAR(256),
    FamilyGUID NVARCHAR(256),
    HasBulkLoggedData NVARCHAR(256),
    IsSnapshot NVARCHAR(256),
    IsReadOnly NVARCHAR(256),
    IsSingleUser NVARCHAR(256),
    HasBackupChecksums NVARCHAR(256),
    IsDamaged NVARCHAR(256),
    BeginsLogChain NVARCHAR(256),
    HasIncompleteMetaData NVARCHAR(256),
    IsForceOffline NVARCHAR(256),
    IsCopyOnly NVARCHAR(256),
    FirstRecoveryForkID NVARCHAR(256),
    ForkPointLSN NVARCHAR(256),
    RecoveryModel NVARCHAR(256),
    DifferentialBaseLSN NVARCHAR(256),
    DifferentialBaseGUID NVARCHAR(256),
    BackupTypeDescription NVARCHAR(256),
    BackupSetGUID NVARCHAR(256),
    CompressedBackupSize NVARCHAR(256),
    Containment NVARCHAR(256),
    KeyAlgorithm NVARCHAR(32),
    EncryptorThumbprint VARBINARY(20),
    EncryptorType NVARCHAR(32),
    --
    -- Seq added to retain order by
    --
    Seq INT NOT NULL IDENTITY(1, 1)
);



SELECT @sql+=
'INSERT INTO #FileList (BackupFile,depth,[file])
	EXEC master.sys.xp_dirtree '''+value+@DBName+''',0,1; update #FileList set BackupPath='''+value+''' where BackupPath is null;'
 FROM STRING_SPLIT(@BackupPath,',')

exec(@sql)

DELETE from #FileList Where [file]=0

update #FileList set
	DbName =  @DBName,
	BackupDate = convert(datetime,STUFF(STUFF(REPLACE(SUBSTRING(BackupFile, (LEN(BackupFile)-14-charindex('.', reverse(BackupFile))),15),'_',' '), 12, 0, ':'), 15, 0, ':')),
	BackupType =SUBSTRING(BackupFile,(LEN(BackupFile)-charindex(reverse(@DBName), reverse(BackupFile)))+3,LEN(BackupFile)-(LEN(BackupFile)-(charindex(reverse(@DBName), reverse(BackupFile)))+3)-(charindex('.', reverse(BackupFile))+15))
WHERE
	[file]=1 
	
DELETE FROM #FileList where BackupType IS NULL

DELETE FROM #FileList where BackupDate<(select MAX(BackupDate) FROM #FileList where BackupType IN ('FULL','FULL_COPY_ONLY'))

select * from #FileList

--DELETE FROM #FileList where BackupDate<(
--select top 1 create_date FROM sys.master_files m 
--			INNER JOIN sys.databases d ON m.database_id=d.database_id 
--			where 
--				m.file_id=1 and m.type=0  and d.name=@DBName)

 
SET @HeadersSQL += 
N'INSERT INTO #Headers WITH (TABLOCK)
  (BackupName, BackupDescription, BackupType, ExpirationDate, Compressed, Position, DeviceType, UserName, ServerName
  ,DatabaseName, DatabaseVersion, DatabaseCreationDate, BackupSize, FirstLSN, LastLSN, CheckpointLSN, DatabaseBackupLSN
  ,BackupStartDate, BackupFinishDate, SortOrder, CodePage, UnicodeLocaleId, UnicodeComparisonStyle, CompatibilityLevel
  ,SoftwareVendorId, SoftwareVersionMajor, SoftwareVersionMinor, SoftwareVersionBuild, MachineName, Flags, BindingID
  ,RecoveryForkID, Collation, FamilyGUID, HasBulkLoggedData, IsSnapshot, IsReadOnly, IsSingleUser, HasBackupChecksums
  ,IsDamaged, BeginsLogChain, HasIncompleteMetaData, IsForceOffline, IsCopyOnly, FirstRecoveryForkID, ForkPointLSN
  ,RecoveryModel, DifferentialBaseLSN, DifferentialBaseGUID, BackupTypeDescription, BackupSetGUID, CompressedBackupSize';
  
IF @MajorVersion >= 11
  SET @HeadersSQL += NCHAR(13) + NCHAR(10) + N', Containment';


IF @MajorVersion >= 13 OR (@MajorVersion = 12 AND @BuildVersion >= 2342)
  SET @HeadersSQL += N', KeyAlgorithm, EncryptorThumbprint, EncryptorType';

SET @HeadersSQL += N')' + NCHAR(13) + NCHAR(10);
SET @HeadersSQL += N'EXEC (''RESTORE HEADERONLY FROM DISK=''''{Path}'''''')';

select @sql+=REPLACE(@HeadersSQL, N'{Path}', BackupPath+DbName+'\'+BackupType+'\'+BackupFile) 
from #FileList 
order by BackupDate

exec(@sql)


--FULL

--SELECT top 1 @sql=N'RESTORE DATABASE ' +QUOTENAME(@DBName) + N' FROM DISK = ''' + BackupPath+DbName+'\'+BackupType+'\'+BackupFile + N''' WITH NORECOVERY' + NCHAR(13) 
--	FROM 
--		#FileList 
--	WHERE 
--		BackupType IN ('FULL','FULL_COPY_ONLY')
--	ORDER BY
--		BackupDate ASC
--	EXECUTE @sql = [dbo].[CommandExecute] @Command = @sql, @CommandType = 'RESTORE FULL DATABASE', @Mode = 1, @DatabaseName = @DBName, @LogToTable = 'Y', @Execute = 'Y';




select * from #Headers






IF(SELECT COUNT(1) FROM #FileList WHERE BackupType='LOG') >1
	BEGIN
		DECLARE BackupFiles CURSOR FOR
				SELECT BackupPath+DbName+'\'+BackupType+'\'+BackupFile as FullBackupPath
				FROM #FileList f1
				WHERE f1.BackupType='LOG'  
				  ORDER BY f1.BackupDate;
		
			OPEN BackupFiles;

			-- Loop through all the files for the database  
		FETCH NEXT FROM BackupFiles INTO @BackupFile, @BackupDate;
		WHILE @@FETCH_STATUS = 0
			BEGIN
	
				SET @sql = REPLACE(@HeadersSQL, N'{Path}', BackupPath+DbName+'\'+BackupType+'\'+BackupFile);
				exec(@sql)

				SELECT 
					@LogFirstLSN = CAST(FirstLSN AS NUMERIC(25, 0)), 
					@LogLastLSN = CAST(LastLSN AS NUMERIC(25, 0)),
					@DatabaseLastLSN = CAST(f.redo_start_lsn AS NUMERIC(25, 0)) 
				FROM 
					#Headers h
					INNER JOIN master.sys.databases d ON d.name=SUBSTRING(@RestoreDatabaseName, 2, LEN(@RestoreDatabaseName) - 2)
					INNER JOIN master.sys.master_files f ON d.database_id = f.database_id
				WHERE 
					f.file_id = 1 AND h.BackupType = 2;

				DELETE FROM #Headers WHERE BackupType = 2;

					select 
				@LogFirstLSN as '@LogFirstLSN' ,
				@LogLastLSN as '@LogLastLSN' ,
				@FullLastLSN as '@FullLastLSN' ,
				@DatabaseLastLSN as '@DatabaseLastLSN',
				@DiffLastLSN as '@DiffLastLSN'

				IF (@FullLastLSN <= @LogLastLSN AND @LogFirstLSN <= @DatabaseLastLSN AND @DatabaseLastLSN < @LogLastLSN ) --AND
				--(@RestoreDiff = 1 AND @LogFirstLSN <= @DiffLastLSN ) OR (@RestoreDiff = 0 AND @LogFirstLSN <= @FullLastLSN )
				BEGIN
					SET @sql = N'RESTORE LOG ' + @RestoreDatabaseName + N' FROM DISK = ''' + @BackupPathLog + @BackupFile + N''' WITH NORECOVERY' ;

					IF (@BackupDate>@StopAt)
					BEGIN
						SET @sql+= ', STOPAT='''+cast(@StopAtDateTime as varchar(max))+'''';
					END
					SET @sql += NCHAR(13);
				
 					EXECUTE @sql = [dbo].[CommandExecute] @Command = @sql, @CommandType = 'RESTORE LOG', @Mode = 1, @DatabaseName = @Database, @LogToTable = 'Y', @Execute = 'Y';	
				END
				ELSE
				BEGIN
					print @BackupFile+'skipped'
				END
			
				FETCH NEXT FROM BackupFiles INTO @BackupFile, @BackupDate;
			END;
	
		CLOSE BackupFiles;

		DEALLOCATE BackupFiles;  
	END
	ELSE
	BEGIN
		print 'There is no log backup to apply'
	END



 

-- Wait for the replica to start communicating
begin try
declare @conn bit
declare @count int
declare @replica_id uniqueidentifier 
declare @group_id uniqueidentifier
set @conn = 0
set @count = 30 -- wait for 5 minutes 

if (serverproperty('IsHadrEnabled') = 1)
	and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty('ComputerNamePhysicalNetBIOS') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
	and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
begin
    select @group_id = ags.group_id from master.sys.availability_groups as ags where name = @AgName
	select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
	while @conn <> 1 and @count > 0
	begin
		set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
		if @conn = 1
		begin
			-- exit loop when the replica is connected, or if the query cannot find the replica status
			break
		end
		waitfor delay '00:00:10'
		set @count = @count - 1
	end
end
end try
begin catch
	-- If the wait loop fails, do not stop execution of the alter database statement
end catch


SET @sql = N'ALTER DATABASE ['+@DBName+'] SET HADR AVAILABILITY GROUP = ['+@AgName+'];' + NCHAR(13);
EXECUTE [dbo].[CommandExecute] @Command = @sql, @CommandType = 'ALTER AVG', @Mode = 1, @DatabaseName = @DBName, @LogToTable = 'Y', @Execute = 'Y';




/*


select * from #FileList
--LOG
IF(@ContinueWithLog=1)
BEGIN
	select @sql = N'RESTORE LOG ' + @DBName + N' FROM DISK = ''' + @BackupFileFullPath +'LOG\'+ BackupFile + N''' WITH NORECOVERY; '  FROM
	#FileList 
	WHERE 
		BackupType='LOG'
	ORDER BY
		BackupDate ASC

	EXECUTE @sql = [dbo].[CommandExecute] @Command = @sql, @CommandType = 'RESTORE LOG', @Mode = 1, @DatabaseName = @DBName, @LogToTable = 'Y', @Execute = 'Y';	
				

END


--HADR
IF(@HadrSET=1)
BEGIN
-- Wait for the replica to start communicating
begin try
	declare @conn bit
	declare @count int
	declare @replica_id uniqueidentifier 
	declare @group_id uniqueidentifier
	set @conn = 0
	set @count = 30 -- wait for 5 minutes 

	if (serverproperty('IsHadrEnabled') = 1)
		and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty('ComputerNamePhysicalNetBIOS') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
		and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
	begin
		select @group_id = ags.group_id from master.sys.availability_groups as ags where name = @AgName
		select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
		while @conn <> 1 and @count > 0
		begin
			set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
			if @conn = 1
			begin
				-- exit loop when the replica is connected, or if the query cannot find the replica status
				break
			end
			waitfor delay '00:00:10'
			set @count = @count - 1
		end
	end
	end try
	begin catch
		-- If the wait loop fails, do not stop execution of the alter database statement
	end catch


	SET @sql = N'ALTER DATABASE ['+@DBName+'] SET HADR AVAILABILITY GROUP = ['+@AgName+'];' + NCHAR(13);
	EXECUTE [dbo].[CommandExecute] @Command = @sql, @CommandType = 'ALTER AVG', @Mode = 1, @DatabaseName = @DBName, @LogToTable = 'Y', @Execute = 'Y';
END

 




 	
			 
				 


*/