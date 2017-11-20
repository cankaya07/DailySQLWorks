USE master

GO

GRANT EXECUTE ON master.dbo.xp_sqlagent_notify TO RSExecRole

GO

GRANT EXECUTE ON master.dbo.xp_sqlagent_enum_jobs TO RSExecRole

GO

GRANT EXECUTE ON master.dbo.xp_sqlagent_is_starting TO RSExecRole

GO

USE msdb

GO

-- Permissions for SQL Agent SP's

GRANT EXECUTE ON msdb.dbo.sp_help_category TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_add_category TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_add_job TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_add_jobserver TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_add_jobstep TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_add_jobschedule TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_help_job TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_delete_job TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_help_jobschedule TO RSExecRole

GO

GRANT EXECUTE ON msdb.dbo.sp_verify_job_identifiers TO RSExecRole

GO

GRANT SELECT ON msdb.dbo.sysjobs TO RSExecRole

GO

GRANT SELECT ON msdb.dbo.syscategories TO RSExecRole

GO