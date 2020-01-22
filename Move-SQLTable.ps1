 
function Move-SQLTable
{
    [CmdletBinding()]
    param( 
  
        [Parameter(Mandatory=$true)]
        [string] $SourceSQLInstance,
 
        [Parameter(Mandatory=$true)]
        [string] $SourceDatabase,        
         
        [Parameter(Mandatory=$true)]
        [string] $TargetSQLInstance,
         
        [Parameter(Mandatory=$true)]
        [string] $TargetDatabase,

        [Parameter(Mandatory=$true)]
        [string] $TargetSchema,
 
        [Parameter(Mandatory=$false)]
        [int] $BulkCopyBatchSize = 10000,
 
        [Parameter(Mandatory=$false)]
        [int] $BulkCopyTimeout = 600   
  
    )
  
    Write-Host "Script started.."
    $source = 'namespace System.Data.SqlClient
    {    
        using Reflection;
            public static class SqlBulkCopyExtension
            {
                const String _rowsCopiedFieldName = "_rowsCopied";
                static FieldInfo _rowsCopiedField = null;
                public static int RowsCopiedCount(this SqlBulkCopy bulkCopy)
                {
                    if (_rowsCopiedField == null) _rowsCopiedField = typeof(SqlBulkCopy).GetField(_rowsCopiedFieldName, BindingFlags.NonPublic | BindingFlags.GetField | BindingFlags.Instance);            
                    return (int)_rowsCopiedField.GetValue(bulkCopy);
                }
            }
    }
    '
    #Add-Type -ReferencedAssemblies 'System.Data.dll' -TypeDefinition $source
    $null = [Reflection.Assembly]::LoadWithPartialName("System.Data")
  
    $sourceConnStr = "Data Source=$SourceSQLInstance;Initial Catalog=$SourceDatabase;Integrated Security=True;"
    $TargetConnStr = "Data Source=$TargetSQLInstance;Initial Catalog=$TargetDatabase;Integrated Security=True;"
    $startTime="";      
    $endTime ="";
    try
    {    
        write-host 'module loaded'
        $sourceSQLServer = New-Object Microsoft.SqlServer.Management.Smo.Server $SourceSQLInstance
        $sourceDB = $sourceSQLServer.Databases[$SourceDatabase]
        $sourceConn  = New-Object System.Data.SqlClient.SQLConnection($sourceConnStr)
     
        $sourceConn.Open()
 
        foreach($table in $sourceDB.Tables)
        {
            $startTime = Get-Date
            $tableName = $table.Name
            $schemaName = $table.Schema
            $tableAndSchema = "$schemaName.$tableName"
            $destTableAndSchema = "$TargetSchema.$tableName"

           
             
            $sql = "SELECT * FROM $tableAndSchema"
            $sqlCommand = New-Object system.Data.SqlClient.SqlCommand($sql, $sourceConn) 
            [System.Data.SqlClient.SqlDataReader] $sqlReader = $sqlCommand.ExecuteReader()   
            
            $bulkCopy = New-Object Data.SqlClient.SqlBulkCopy($TargetConnStr, [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity)
            $bulkCopy.DestinationTableName = $destTableAndSchema
            $bulkCopy.BulkCopyTimeOut = $BulkCopyTimeout
            $bulkCopy.NotifyAfter = 500000;
            $bulkCopy.BatchSize = $BulkCopyBatchSize


            $bulkCopy.Add_SqlRowscopied({Write-Host "$($args[1].RowsCopied) rows copied" }) # Thanks for simplifying this, CookieMonster!
            Write-Host $startTime $tableAndSchema "Inserting rows..." 
            # WriteToServer, however you want to do it.
            [void]$bulkCopy.WriteToServer($sqlReader)
            # "Note: This count does not take into consideration the number of rows actually inserted when Ignore Duplicates is set to ON."
            $total = [System.Data.SqlClient.SqlBulkCopyExtension]::RowsCopiedCount($bulkcopy)
            $endTime=Get-Date
            Write-Host "$endTime $total total rows written in $($($endTime-$startTime).TotalSeconds) second(s)"
            $sqlReader.Close()
            $bulkCopy.Close()
        }
        $sourceConn.Close()
    }
    catch
    {
        [Exception]$ex = $_.Exception
        write-host $ex.Message
    }
    finally
    {
        #Return value if any
    }
    Write-Host "Script finished.."
}

 
Move-SQLTable  -SourceSQLInstance sourceSQLInstance -SourceDatabase sourceDatabase  -TargetSQLInstance  targetSQLInstance -TargetDatabase targetDatabase -TargetSchema targetSchema -BulkCopyBatchSize 500000
 

