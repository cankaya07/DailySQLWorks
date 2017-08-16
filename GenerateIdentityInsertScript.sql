USE [SQLAdmin]
GO

/****** Object:  UserDefinedFunction [can].[GenerateIdentityInsertScript]    Script Date: 8/16/2017 3:12:26 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [can].[GenerateIdentityInsertScript]
(
	 @tableSchema VARCHAR(128)='',
	 @tableName VARCHAR(128)=''
)
RETURNS nvarchar(max)
AS
BEGIN
DECLARE @Sql NVARCHAR(MAX)=''

	SET @tableName = REPLACE(REPLACE(@tableName,'[',''),']','')
	SET @tableSchema = REPLACE(REPLACE(@tableSchema,'[',''),']','')

	SET @Sql = @Sql+char(10)+'BEGIN TRY'+CHAR(10)
	SET @Sql = @Sql+'BEGIN TRANSACTION'+char(10)
	SET @Sql = @Sql+char(9)+'ALTER TABLE '+@tableSchema+'.'+@tableName+' SET (LOCK_ESCALATION = TABLE)'+char(10)
	SET @Sql = @Sql+char(9)+'SET IDENTITY_INSERT '+@tableSchema+'.'+@tableName+' ON'+char(10);
	 
	 ;WITH GeneralColumn AS (
		select DISTINCT c.name,column_id
		from  [IB_GENEL].sys.indexes (NOLOCK) i
		INNER JOIN [IB_GENEL].sys.tables (NOLOCK) t ON i.object_id=t.object_id
		INNER JOIN [IB_GENEL].sys.schemas (NOLOCK) s ON t.schema_id=s.schema_id
		INNER JOIN [IB_GENEL].sys.columns (NOLOCK) c ON t.object_id=c.object_id
		INNER JOIN [IB_GENEL].sys.types (NOLOCK) type ON c.system_type_id=type.system_type_id
		INNER JOIN [IB_GENEL].sys.filegroups (NOLOCK) f ON i.data_space_id=f.data_space_id
		where 
		t.name=@tableName and s.name=@tableSchema
		), Extended AS (
		select DISTINCT STUFF((select    ',' + name 
		 from  GeneralColumn 
		  order by column_id
					FOR XML PATH('')) ,1,1,'') AS Txt from GeneralColumn as Results
		)
	 
	SELECT DISTINCT
	@Sql = @Sql+char(9)+'INSERT INTO '+@tableSchema+'.'+@tableName+' ('+Txt+')
			SELECT '+Txt+' FROM [LINKED_TESTLSTR].[IB_GENEL].'+@tableSchema+'.'+@tableName+' WITH (HOLDLOCK TABLOCKX)'+char(10)
	from Extended
	SET @Sql = @Sql+char(9)+'SET IDENTITY_INSERT '+@tableSchema+'.'+@tableName+' OFF'+char(10);
	SET @Sql = @Sql+char(9)+'COMMIT TRANSACTION'+char(10)+'END TRY'+char(10)+'BEGIN CATCH'+char(10)+char(9)+'PRINT ''ERROR OCCURED''+ ERROR_MESSAGE()+ cast(ERROR_NUMBER() as varchar)'+char(10)+
	char(9)+'ROLLBACK TRANSACTION'+char(10)+'END CATCH'
	RETURN @Sql;

END

GO

