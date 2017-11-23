$date = Get-Date -format d
Backup-RsEncryptionKey -ComputerName Report01 -ReportServerInstance DEVELOPMENT -Password password -KeyPath J:\SSRS_Backup\DEVELOPMENT_$date.snk
Backup-RsEncryptionKey -ComputerName Report01 -ReportServerInstance PREPROD -Password password -KeyPath J:\SSRS_Backup\PREPROD_$date.snk
Backup-RsEncryptionKey -ComputerName Report01 -ReportServerInstance PRODUCTION -Password password -KeyPath J:\SSRS_Backup\PRODUCTION_$date.snk
Backup-RsEncryptionKey -ComputerName Report01 -ReportServerInstance UNITTEST -Password password -KeyPath J:\SSRS_Backup\UNITTEST_$date.snk
Backup-RsEncryptionKey -ComputerName Report01 -ReportServerInstance TEST -Password password -KeyPath J:\SSRS_Backup\TEST_$date.snk
