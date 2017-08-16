USE [SQLAdmin]
GO

/****** Object:  StoredProcedure [can].[MoveNonClusteredIndexToAnotherFileGroup]    Script Date: 8/16/2017 3:02:20 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [can].[MoveNonClusteredIndexToAnotherFileGroup] 
(        
 @DBName sysname,   
 @SchemaName varchar(max) = 'dbo',       
 @ObjectName Varchar(Max),        
 @indexName varchar(max) = null,  
 @FileGroupName varchar(100)  
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
)  
  
DECLARE @DistinctIndexData Table  
(  
	Id Int IDENTITY(1,1)  
	,ObjectName sysname  
	,IndexName sysname  
	,Is_Unique Bit  
	,Type_Desc Varchar(25)  
	,Is_Padded Bit  
	,Ignore_Dup_Key Bit  
	,Allow_Row_Locks Bit  
	,Allow_Page_Locks Bit  
	,Fill_Factor Int  
	,FileGroupName Varchar(Max) 
	,Has_Filter Bit
	,Filter_Definition NVarchar(Max)  
)
 
SET @indexSQL =   
'SELECT 
	so.Name as ObjectName, si.Name as indexName,
	si.is_unique,si.Type_Desc
	,si.is_padded,si.ignore_dup_key,si.allow_row_locks,
	si.Allow_Page_Locks,si.Fill_Factor,sic.is_descending_key  
	,sc.Name as ColumnName,sic.is_included_column,
	sf.Name as FileGroupName,
	si.has_filter,
	si.filter_definition 
FROM '+ QUOTENAME(@DBName) + '.sys.Objects so 
INNER JOIN '+ QUOTENAME(@DBName) + '.sys.schemas sch ON so.schema_id=sch.schema_id
INNER JOIN '+ QUOTENAME(@DBName) + '.sys.indexes si ON so.Object_id = si.Object_id 
INNER JOIN '+ QUOTENAME(@DBName) + '.sys.FileGroups sf ON sf.Data_Space_id = si.Data_Space_id 
INNER JOIN '+ QUOTENAME(@DBName) + '.sys.index_columns sic ON si.Object_id = sic.Object_id AND si.index_id = sic.index_id 
INNER JOIN '+ QUOTENAME(@DBName) + '.sys.Columns sc ON sic.Column_id = sc.Column_id and sc.Object_id = sic.Object_id 
WHERE so.Name = ''' + @ObjectName  + '''
AND sch.name = '''+@SchemaName+''''
--AND si.Type_Desc = ''NONCLUSTERED'''  
  
 IF(@indexName IS NOT NULL)  
 BEGIN  
  SET @indexSQL = @indexSQL + ' AND si.Name = ''' + @indexName + ''''  
 END  
  
 SET @indexSQL = @indexSQL + ' ORDER BY ObjectName, indexName, sic.Key_Ordinal' 


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
  PRINT 'Object does not have any nonclustered indexes to move'   
  RETURN -1;   
 END  

-------------Get the distinct index rows in to a variable----------------------    
INSERT INTO @DistinctIndexData  
SELECT DISTINCT   
ObjectName,IndexName,Is_Unique,Type_Desc,Is_Padded,Ignore_Dup_Key,Allow_Row_Locks,Allow_Page_Locks,Fill_Factor,FileGroupName,Has_Filter,Filter_Definition 
FROM @WholeIndexData
WHERE ObjectName = @ObjectName  

SET @indexKeySQL = ''  
SET @IncludeColSQL = ''  
  
  -------------Get the current index row to be processed----------------------  
  SELECT   
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
  FROM @DistinctIndexData   
  
  -------------Check if the index is already not part of that FileGroup----------------------  
  
  IF(@ExistingFGName = @FileGroupName)  
  BEGIN  
   PRINT 'index ' +  @IndName + ' is NOT moved as it is already part of the FileGroup ' + @FileGroupName + '.'  
   RETURN -1; 
  END  
  
  ------- Construct the index key string along with the direction--------------------  
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
    
  --PRINT @indexKeySQL   
    
  ------ Construct the Included Column string --------------------------------------  
  SELECT   
   @IncludeColSQL =   
   CASE  
   WHEN @IncludeColSQL = '' THEN (@IncludeColSQL + QUOTENAME(ColumnName))   
   ELSE (@IncludeColSQL + ',' + QUOTENAME(ColumnName))   
   END   
  FROM @WholeIndexData  
  WHERE ObjectName = @ObjectName   
  AND IndexName = @IndName   
  AND Is_Included_Column = 1   
    
--PRINT @IncludeColSQL  
  
  -------------Construct the final Create index statement----------------------  
  SELECT 
  @FinalSQL = 'CREATE ' + @IsUnique + @Type + ' INDEX ' + QUOTENAME(@IndName) 
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
  + 'DROP_EXISTING = ON,'   
  + 'ONLINE = OFF,'  
  + 'FILLFACTOR = ' + CAST(@FillFactor AS Varchar(3))  
  + ') ON ' + QUOTENAME(@FileGroupName)  
  
  --PRINT @FinalSQL  

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

