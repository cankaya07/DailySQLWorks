USE [SQLAdmin]
GO

/****** Object:  StoredProcedure [can].[MoveIndexToAnotheFileGroup]    Script Date: 8/16/2017 3:02:00 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [can].[MoveIndexToAnotheFileGroup]
(
 @DBName varchar(max),   
 @SchemaName varchar(max),       
 @ObjectName varchar(Max),        
 @indexName varchar(max) = null,  
 @FileGroupName varchar(100),
 @IndexType varchar(100) = 'NONCLUSTERED',
 @Online bit =0 
)  
AS
BEGIN

DECLARE @return_value int;
print @IndexType
exec @return_value= can.MoveIndexToAnotherFileGroupCheck @DBName,@SchemaName,@ObjectName,@indexName,@FileGroupName,@IndexType,@Online

IF (@return_value = 0) 
BEGIN	
	RETURN 0; 
END
ELSE
BEGIN
	IF (@IndexType='HEAP')
	BEGIN
		exec @return_value= can.MoveHeapTableToAnotherFileGroup @DBName,@SchemaName,@ObjectName,@indexName,@FileGroupName,@Online
	END
	ELSE
	BEGIN
		exec @return_value= can.MoveNonClusteredIndexToAnotherFileGroup @DBName,@SchemaName,@ObjectName,@indexName,@FileGroupName
	END
END
END




GO

