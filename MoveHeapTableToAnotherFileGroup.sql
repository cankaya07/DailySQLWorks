USE [SQLAdmin]
GO

/****** Object:  StoredProcedure [can].[MoveHeapTableToAnotherFileGroup]    Script Date: 8/16/2017 3:01:53 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [can].[MoveHeapTableToAnotherFileGroup] 
(        
 @DBName sysname,   
 @SchemaName varchar(max) = 'dbo',       
 @ObjectName Varchar(Max),        
 @indexName varchar(max) = null,  
 @FileGroupName varchar(100),
 @Online bit =1  
)        
WITH RECOMPILE
AS
BEGIN

SET NOCOUNT ON;

DECLARE @schemaID int;

DECLARE @indexSQL NVarchar(Max)  
DECLARE @indexKeySQL NVarchar(Max)  
DECLARE @IncludeColSQL NVarchar(Max)  
DECLARE @FinalSQL NVarchar(Max)  
  
DECLARE @IndName sysname  
DECLARE @IsUnique Varchar(10)  
DECLARE @Type Varchar(25)  
DECLARE @IsPadded Varchar(5)  
DECLARE @IgnoreDupKey Varchar(5) 
DECLARE @AllowRowLocks Varchar(5)  
DECLARE @AllowPageLocks Varchar(5) 
DECLARE @FillFactor Int  
DECLARE @ExistingFGName Varchar(Max) 
DECLARE @FilterDef NVarchar(Max)
  
DECLARE @ErrorMessage NVARCHAR(max)  
DECLARE @SQL nvarchar(max)  
DECLARE @RetVal Bit  

DECLARE @WholeIndexData Table  
(  
	ObjectName sysname  
	,IndexName sysname  
	,Is_Unique Bit  
	,Type_Desc Varchar(25)  
	,Is_Padded Bit  
	,Ignore_Dup_Key Bit  
	,Allow_Row_Locks Bit  
	,Allow_Page_Locks Bit  
	,Fill_Factor Int  
	,Is_Descending_Key Bit  
	,ColumnName sysname  
	,Is_Included_Column Bit  
	,FileGroupName Varchar(Max)
	,Has_Filter Bit
	,Filter_Definition NVarchar(Max)
	,ColumnTypeName nvarchar(max)
	,column_id bigint
	,max_length bigint
	,object_id bigint
)  
 
SET @indexSQL =   
'select 
	t.Name as ObjectName,
	'''' as IndexName,
	i.is_unique,
	i.Type_Desc,
	i.is_padded,
	i.ignore_dup_key,
	i.allow_row_locks,
	i.Allow_Page_Locks,
	i.Fill_Factor,
	0 as Is_Descending_Key,
	c.name as ColumnName,
	0 as Is_Included_Column,
	f.name as FileGroupName,
	i.has_filter,
	i.filter_definition,
	type.name as ColumnTypeName,
	c.column_id,
	c.max_length,
	c.object_id
from '+ QUOTENAME(@DBName) + '.sys.indexes i
		INNER JOIN '+ QUOTENAME(@DBName) + '.sys.tables t ON i.object_id=t.object_id
		INNER JOIN '+ QUOTENAME(@DBName) + '.sys.schemas s ON t.schema_id=s.schema_id
		INNER JOIN '+ QUOTENAME(@DBName) + '.sys.columns c ON t.object_id=c.object_id
		INNER JOIN '+ QUOTENAME(@DBName) + '.sys.types type ON c.system_type_id=type.system_type_id
		INNER JOIN '+ QUOTENAME(@DBName) + '.sys.filegroups f ON i.data_space_id=f.data_space_id
where 1=1
AND c.user_type_id=c.system_type_id and type.system_type_id=type.user_type_id
and i.type=0 
--and f.name=''PRIMARY''
AND t.Name = ''' + @ObjectName  + '''
AND s.name = '''+@SchemaName+'''
--AND type.name IN (''int'',''bigint'',''bit'',''char'',''decimal'',''float'',''date'',''datetime'',''smallint'',''datetime2'',''numeric'',''uniqueidentifier'',''varchar'',''tinyint'')
ORDER BY c.column_id' 



  -------------Insert the Index Data in to a variable----------------------   
  
BEGIN TRY  
  INSERT INTO @WholeIndexData  
  EXEC sp_executesql @indexSQL  
 END TRY  
 BEGIN CATCH  
  PRINT ERROR_MESSAGE()   
  RETURN -1;  
 END CATCH  
  
 --Check if any indexes are there on the object. Otherwise exit  
 IF (SELECT COUNT(*) FROM @WholeIndexData) = 0  
 BEGIN  
  PRINT 'Object is not HEAP'   
  RETURN -1;   
 END  


 --select * from @WholeIndexData



---------------Get the distinct index rows in to a variable----------------------    
--INSERT INTO @DistinctIndexData  
--SELECT DISTINCT   
--ObjectName,IndexName,Is_Unique,Type_Desc,Is_Padded,Ignore_Dup_Key,Allow_Row_Locks,Allow_Page_Locks,Fill_Factor,FileGroupName,Has_Filter,Filter_Definition 
--FROM @WholeIndexData
--WHERE ObjectName = @ObjectName  

SET @indexKeySQL = ''  
SET @IncludeColSQL = ''  
  
  -------------Get the current index row to be processed----------------------  
  SELECT   top 1
   @IndName   = IndexName  
   ,@Type   = Type_Desc
   ,@ExistingFGName = FileGroupName
   ,@IsUnique  = CASE WHEN Is_Unique = 1 THEN 'UNIQUE ' ELSE '' END  
   ,@IsPadded  = CASE WHEN Is_Padded = 0 THEN 'OFF,' ELSE 'ON,'  END  
   ,@IgnoreDupKey = CASE WHEN Ignore_Dup_Key = 0 THEN 'OFF,' ELSE 'ON,' END  
   ,@AllowRowLocks = CASE WHEN Allow_Row_Locks = 0 THEN 'OFF,' ELSE 'ON,' END 
   ,@AllowPageLocks = CASE WHEN Allow_Page_Locks = 0 THEN 'OFF,' ELSE 'ON,' END  
   ,@FillFactor  = CASE WHEN Fill_Factor = 0 THEN 100 ELSE Fill_Factor END  
   ,@FilterDef  = CASE WHEN Has_Filter = 1 THEN (' WHERE ' + Filter_Definition) ELSE '' END  
  FROM @WholeIndexData   
  
  -------------Check if the index is already not part of that FileGroup----------------------  
  
  IF(@ExistingFGName = @FileGroupName)  
  BEGIN  
   PRINT 'index ' +  @IndName + ' is NOT moved as it is already part of the FileGroup ' + @FileGroupName + '.'  
   RETURN -1; 
  END  
  
  ------- Construct the index key string along with the direction--------------------  

IF(@Type ='HEAP')
BEGIN
	SET @Type = 'CLUSTERED'

	IF EXISTS(select * from @WholeIndexData where ColumnTypeName IN ('int','bigint','bit','char','decimal','float','date','datetime','smallint','datetime2','numeric','uniqueidentifier','tinyint'))
	BEGIN

		SELECT   top 16
		@indexKeySQL =   
		COALESCE(@indexKeySQL + ', ', '') + QUOTENAME(ColumnName) +' ASC'
		FROM @WholeIndexData  
		WHERE ObjectName = @ObjectName
		AND ColumnTypeName IN ('int','bigint','bit','char','decimal','float','date','datetime','smallint','datetime2','numeric','uniqueidentifier','tinyint')

		SET @indexKeySQL =SUBSTRING(@indexKeySQL,3,LEN(@indexKeySQL)-1)
	END
	ELSE
	BEGIN	
		--i am the lucky day as a dba
		SELECT   top 1
		@indexKeySQL =   
		COALESCE(@indexKeySQL + ', ', '') + QUOTENAME(ColumnName) +' ASC'
		FROM @WholeIndexData  
		WHERE ObjectName = @ObjectName

		SET @indexKeySQL =SUBSTRING(@indexKeySQL,3,LEN(@indexKeySQL)-1)
	END

	--CHECK ONLINE OFFLINE
	IF EXISTS(select * from @WholeIndexData WHERE ObjectName = @ObjectName AND ColumnTypeName IN ('text', 'ntext', 'image'))
	BEGIN 
	set @Online = 0;
	END
	
END
ELSE
BEGIN
	SELECT   
	@indexKeySQL =   
	CASE  
	WHEN @indexKeySQL = '' THEN (@indexKeySQL + QUOTENAME(ColumnName) + CASE WHEN Is_Descending_Key = 0 THEN ' ASC' ELSE ' DESC' END)   
	ELSE (@indexKeySQL + ',' + QUOTENAME(ColumnName) + CASE WHEN Is_Descending_Key = 0 THEN ' ASC' ELSE ' DESC' END)   
	END  
	FROM @WholeIndexData  
	WHERE ObjectName = @ObjectName   
	AND IndexName = @IndName   
	AND Is_Included_Column = 0  
END 



    
 -- PRINT @indexKeySQL   
    
  ------ Construct the Included Column string --------------------------------------  
  --SELECT   
  -- @IncludeColSQL =   
  -- CASE  
  -- WHEN @IncludeColSQL = '' THEN (@IncludeColSQL + QUOTENAME(ColumnName))   
  -- ELSE (@IncludeColSQL + ',' + QUOTENAME(ColumnName))   
  -- END   
  --FROM @WholeIndexData  
  --WHERE ObjectName = @ObjectName   
  --AND IndexName = @IndName   
  --AND Is_Included_Column = 1   
    
--PRINT @IncludeColSQL  
  
  -------------Construct the final Create index statement----------------------  
  SELECT 
  @FinalSQL = 'CREATE ' + @IsUnique + @Type + ' INDEX ' + QUOTENAME(+'FORMOVEHEAP_'+@ObjectName) 
  + ' ON ' + QUOTENAME(@DBName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName)  
  + '(' + @indexKeySQL + ') '   
  + CASE WHEN LEN(@IncludeColSQL) <> 0 THEN  'INCLUDE(' + @IncludeColSQL + ') ' ELSE '' END
  + @FilterDef  
  + ' WITH ('   
  + 'PAD_INDEX = ' + @IsPadded   
  + 'IGNORE_DUP_KEY = ' + @IgnoreDupKey  
  + 'ALLOW_ROW_LOCKS  = ' + @AllowRowLocks   
  + 'ALLOW_PAGE_LOCKS  = ' + @AllowPageLocks   
  + 'SORT_IN_TEMPDB = OFF,'   
 -- + 'DROP_EXISTING = ON,'  
  + 'ONLINE = '+CASE WHEN @Online = 0 THEN  'OFF' ELSE 'ON' END +','  
  + 'FILLFACTOR = ' + CAST(@FillFactor AS Varchar(3))  
  + ') ON ' + QUOTENAME(@FileGroupName)  
  
  SET @FinalSQL=@FinalSQL+'   DROP INDEX '+QUOTENAME(+'FORMOVEHEAP_'+@ObjectName) + ' ON ' + QUOTENAME(@DBName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@ObjectName)  
 -- PRINT @FinalSQL  

  -------------Execute the Create index statement to move to the specified filegroup----------------------  
BEGIN TRY  
EXEC sp_executesql @FinalSQL  
--PRINT @FinalSQL
PRINT 'index ' +  @IndName + ' on Object ' + @ObjectName + ' is moved successfully.' 
END TRY  
BEGIN CATCH  
	PRINT 'ERROR OCCURED! ' +  @IndName +','+ @ObjectName +' '+ ERROR_MESSAGE()+ char(10)+'Executed script is:'+@FinalSQL
END CATCH   
   
   
--PRINT 'The procedure completed successfully.'

RETURN 1;

END


GO

