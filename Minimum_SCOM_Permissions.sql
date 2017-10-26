--Can KAYA
--cankaya07@gmail.com
--23.10.2017





USE [master]
GO
IF NOT EXISTS (select * from sys.syslogins where loginname='NT SERVICE\HealthService')
BEGIN
	CREATE LOGIN [NT SERVICE\HealthService] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
END
GRANT VIEW ANY DATABASE TO [NT SERVICE\HealthService];
GRANT VIEW ANY DEFINITION TO [NT SERVICE\HealthService];
GRANT VIEW SERVER STATE TO [NT SERVICE\HealthService];
GRANT SELECT on sys.database_mirroring_witnesses to [NT SERVICE\HealthService];
GO

USE [msdb];
EXEC sp_addrolemember @rolename='PolicyAdministratorRole', @membername='NT SERVICE\HealthService';
EXEC sp_addrolemember @rolename='SQLAgentReaderRole', @membername='NT SERVICE\HealthService';

DECLARE @command2 nvarchar(MAX) ='';
SELECT @command2 = @command2 + 'USE ['+db.name+'];
CREATE USER [NT SERVICE\HealthService] 
FOR LOGIN [NT SERVICE\HealthService];'
FROM sys.databases db 
left join sys.dm_hadr_availability_replica_states hadrstate 
on db.replica_id = hadrstate.replica_id 
WHERE db.database_id <> 2 
AND db.user_access = 0 
AND db.state = 0 
AND db.is_read_only = 0 
AND (hadrstate.role = 1 or hadrstate.role is null);

EXECUTE sp_executesql @command2;

SET @command2='';
 






--For single line for dbatools
Invoke-Sqlcmd2 -ServerInstance "$$SQLSERVERINSTANCE$$" -Query "USE [master] IF NOT EXISTS (select * from sys.syslogins where loginname='NT SERVICE\HealthService') BEGIN CREATE LOGIN [NT SERVICE\HealthService] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english] END GRANT VIEW ANY DATABASE TO [NT SERVICE\HealthService]; GRANT VIEW ANY DEFINITION TO [NT SERVICE\HealthService]; GRANT VIEW SERVER STATE TO [NT SERVICE\HealthService]; GRANT SELECT on sys.database_mirroring_witnesses to [NT SERVICE\HealthService];USE [msdb];EXEC sp_addrolemember @rolename='PolicyAdministratorRole', @membername='NT SERVICE\HealthService';EXEC sp_addrolemember @rolename='SQLAgentReaderRole', @membername='NT SERVICE\HealthService';DECLARE @command2 nvarchar(MAX);" -Verbose