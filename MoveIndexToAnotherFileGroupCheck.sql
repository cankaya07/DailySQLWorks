USE [SQLAdmin]
GO

/****** Object:  StoredProcedure [can].[MoveIndexToAnotherFileGroupCheck]    Script Date: 8/16/2017 3:02:07 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [can].[MoveIndexToAnotherFileGroupCheck](
 @DBName varchar(max),   
 @SchemaName varchar(max),       
 @ObjectName varchar(Max),        
 @indexName varchar(max) = null,  
 @FileGroupName varchar(100),
 @IndexType varchar(100)='NONCLUSTERED',
 @Online bit =0
)        
WITH RECOMPILE
AS  
BEGIN
	
DECLARE @ErrorMessage NVARCHAR(max)  
DECLARE @SQL nvarchar(max)  
DECLARE @RetVal Bit  

-------------Validate arguments----------------------   
  
IF (@Online = 1 AND SERVERPROPERTY('EngineEdition') <> 3) 
BEGIN  
 PRINT 'VALIDATION ERROR: SQL Server Enterprise edition is required for online index operations.';
 RETURN 0;
END  

IF(@DBName IS NULL)  
BEGIN  
 PRINT 'VALIDATION ERROR: Database Name must be supplied.';
 RETURN 0;
END  
  
IF(@ObjectName IS NULL)  
BEGIN  
 PRINT 'VALIDATION ERROR: Table or View Name must be supplied.'   
 RETURN 0;
END  
  
IF(@FileGroupName IS NULL)  
BEGIN  
 PRINT 'VALIDATION ERROR: FileGroup Name must be supplied.'
 RETURN 0;
END  
  
--Check for the existence of the Database  
IF NOT EXISTS(SELECT Name FROM sys.databases where Name = @DBName) 
BEGIN 
 PRINT 'VALIDATION ERROR: The specified Database does not exist' 
 RETURN 0;
END

--Check for the existence of the Schema  
SET @SQL = 'select @RetVal = COUNT(*) from ' + QUOTENAME(@DBName) + '.sys.schemas where name='''+@SchemaName+'''';
EXEC sp_executesql @SQL,N'@RetVal Bit OUTPUT',@RetVal OUTPUT;
IF(@RetVal = 0)
BEGIN
	PRINT 'VALIDATION ERROR: No Schema with the name ' + @SchemaName + ' exists in the Database ' + @DBName
	RETURN 0;
END

--Check for the existence of the FileGroup
SET @SQL = 'select @RetVal = COUNT(*) FROM  ' + QUOTENAME(@DBName) + '.sys.filegroups where name='''+@FileGroupName+'''';
EXEC sp_executesql @SQL,N'@RetVal Bit OUTPUT',@RetVal OUTPUT;
IF(@RetVal = 0)
BEGIN
	PRINT 'VALIDATION ERROR: No FileGroup with the name ' + @FileGroupName + ' exists in the Database ' + @DBName  
	RETURN 0;
END

 --Check for existence of the object  
SET @SQL = 'SELECT @RetVal = COUNT(*) FROM ' + QUOTENAME(@DBName) + '.sys.Objects WHERE type IN (''U'',''V'') AND name = '''+@ObjectName+'''';
EXEC sp_executesql @SQL,N'@RetVal Bit OUTPUT',@RetVal OUTPUT;
IF(@RetVal = 0)
BEGIN
	PRINT 'VALIDATION ERROR: No Table or View with the name ' + @ObjectName + ' exists in the Database ' + @DBName   
	RETURN 0;
END

--Check for existence of index 
SET @SQL = 'SELECT @RetVal = COUNT(*) FROM  ' + QUOTENAME(@DBName) + '.sys.indexes si 
INNER JOIN ' + QUOTENAME(@DBName) + '.sys.Objects so  ON si.Object_id = so.Object_id 
INNER JOIN ' + QUOTENAME(@DBName) + '.sys.schemas sc ON so.schema_id= sc.schema_id
WHERE   so.name = '''+@ObjectName+''' AND si.name =  '''+@indexName+''' AND sc.name ='''+@Schemaname+''''

EXEC sp_executesql @SQL,N'@RetVal Bit OUTPUT',@RetVal OUTPUT;
IF(@RetVal = 0)
BEGIN
	PRINT 'VALIDATION ERROR: No index with the name ' + @indexName + ' exists on the Object ' + @ObjectName
	RETURN 0;   
END

IF(@IndexType<>'HEAP')
BEGIN
	--Check for existence of enabled index 
	SET @SQL = 'SELECT @RetVal = COUNT(*) FROM  ' + QUOTENAME(@DBName) + '.sys.indexes si 
	INNER JOIN ' + QUOTENAME(@DBName) + '.sys.Objects so  ON si.Object_id = so.Object_id 
	INNER JOIN ' + QUOTENAME(@DBName) + '.sys.schemas sc ON so.schema_id= sc.schema_id
	WHERE   so.name = '''+@ObjectName+''' AND si.is_disabled=1 AND si.name =  '''+@indexName+''' AND sc.name ='''+@Schemaname+''''

	EXEC sp_executesql @SQL,N'@RetVal Bit OUTPUT',@RetVal OUTPUT;
	IF(@RetVal > 0)
	BEGIN
		PRINT 'VALIDATION ERROR: ' + @indexName + ' is disabled on the Object ' + @ObjectName
		RETURN 0;   
	END
END


RETURN 1;
END
 

GO

