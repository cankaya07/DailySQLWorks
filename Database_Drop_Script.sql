select 
'EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'''+name+'''' as DeleteBackupHistory,
'USE [master]
'+char(10)+
'ALTER DATABASE '+QUOTENAME(name)+' SET  SINGLE_USER WITH ROLLBACK IMMEDIATE' as SetSingleUser,
'USE [master]
'+char(10)+
'--DROP DATABASE '+ QUOTENAME(name) as DropDatabase,
* from sys.databases where replica_id IS NULL and database_id>4 and name not like '%TempDB'

 