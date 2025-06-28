-- Demo 2: Using REST to take FlashArray snapshots (Improved & Simplified)
-- This demo showcases SQL Server 2025's native integration with Pure Storage FlashArray for near-instant snapshots
-- This is not a production script, but rather a demonstration of the capabilities of SQL Server 2025 and Pure Storage FlashArray integration.
/*
PREREQUISITES:
    - SQL Server 2025 or later
    - 'external rest endpoint enabled' server configuration option
    - Valid API token with at least 'Storage Admin' permissions on the Pure Storage FlashArray
    - Protection Group already configured on the Pure Storage array
    - Purity REST API version 2.44 or later
*/
------------------------------------------------------------
-- Step 1: Enable REST endpoint in SQL Server
------------------------------------------------------------
sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;
GO

------------------------------------------------------------
-- Step 2: Initialize variables and configuration
------------------------------------------------------------
-- Configuration variables (customize these for your environment)
DECLARE @ApiToken        NVARCHAR(255) = N'3b078aa4-94a8-68da-8e7b-04aec357f678'; -- Store securely in production
DECLARE @DatabaseName    NVARCHAR(128) = N'TPCC-4T';
DECLARE @ProtectionGroup NVARCHAR(128) = N'aen-sql-25-a-pg';
DECLARE @BackupS3Bucket  NVARCHAR(255) = N's3://s200.fsa.lab/aen-sql-backups/';

-- Working variables
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(MAX), @MyHeaders NVARCHAR(MAX);
DECLARE @SnapshotName NVARCHAR(255), @ErrorMessage NVARCHAR(MAX);

BEGIN TRY
    ------------------------------------------------------------
    -- Step 3: Authenticate with Pure Storage FlashArray
    ------------------------------------------------------------
    PRINT 'Authenticating with Pure Storage FlashArray...'

    EXEC @ret = sp_invoke_external_rest_endpoint
         @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/login',
         @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',
         @response = @response OUTPUT;

    IF (@ret <> 0)
        THROW 50001, 'Failed to authenticate with Pure Storage array', 1;

    PRINT 'Authentication successful'

    ------------------------------------------------------------
    -- Step 4: Extract authentication token
    ------------------------------------------------------------
    SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"')
    
    IF (@AuthToken IS NULL)
        THROW 50002, 'Failed to extract authentication token from response', 1;
    
    SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}'

    ------------------------------------------------------------
    -- Step 5: Suspend database for snapshot
    ------------------------------------------------------------
    PRINT 'Suspending database for snapshot...'
    ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON

    ------------------------------------------------------------
    -- Step 6: Create Pure Storage snapshot with metadata
    ------------------------------------------------------------
    PRINT 'Creating Pure Storage snapshot...'
    
    -- Generate backup metadata
    DECLARE @InstanceName   NVARCHAR(128) = REPLACE(@@SERVERNAME, '\', '_');
    DECLARE @BackupType     NVARCHAR(20)  = 'SNAPSHOT';
    DECLARE @DateStamp      NVARCHAR(20)  = REPLACE(CONVERT(NVARCHAR, GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR, GETDATE(), 108), ':', ''), ' ', '_');
    DECLARE @BackupFileName NVARCHAR(255) = @InstanceName + '_' + @DatabaseName + '_' + @BackupType + '_' + @DateStamp + '.bkm';
    DECLARE @BackupUrl      NVARCHAR(512) = @BackupS3Bucket + @BackupFileName;
    DECLARE @Payload        NVARCHAR(MAX);

    SET @Payload = N'{  
        "source_names": "' + @ProtectionGroup + '",
        "replicate_now": true,
        "tags": [
            {"copyable": true, "key": "DatabaseName", "value": "' + @DatabaseName + '"},
            {"copyable": true, "key": "SQLInstanceName", "value": "' + @InstanceName + '"},
            {"copyable": true, "key": "BackupTimestamp", "value": "' + @DateStamp + '"},
            {"copyable": true, "key": "BackupType", "value": "' + @BackupType + '"},
            {"copyable": true, "key": "BackupUrl", "value": "' + @BackupUrl + '"}
        ]
    }';

    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/protection-group-snapshots',
        @headers = @MyHeaders,
        @payload = @Payload,
        @response = @response OUTPUT;

    IF (@ret <> 0)
        THROW 50003, 'Failed to create Pure Storage snapshot', 1;

    PRINT 'Snapshot created successfully'

    ------------------------------------------------------------
    -- Step 7: Create metadata-only backup
    ------------------------------------------------------------
    SET @SnapshotName = JSON_VALUE(@response, '$.result.items[0].name')
    
    IF (@SnapshotName IS NULL)
        THROW 50004, 'Failed to extract snapshot name from response', 1;

    PRINT 'Creating metadata-only backup for snapshot: ' + @SnapshotName
    
    BACKUP DATABASE [TPCC-4T] TO URL = @BackupUrl 
    WITH METADATA_ONLY, MEDIADESCRIPTION = @SnapshotName;
    
    PRINT 'Backup completed successfully. File: ' + @BackupUrl

END TRY
BEGIN CATCH
    DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    
    PRINT 'Error occurred: ' + @ErrorMsg
    
    -- Ensure database is unsuspended on any error
    IF (DATABASEPROPERTYEX(@DatabaseName, 'IsDatabaseSuspendedForSnapshotBackup') = 1)
    BEGIN
        ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
        PRINT 'Database unsuspended after error'
    END
    
    -- Re-raise the original error
    RAISERROR(@ErrorMsg, @ErrorSeverity, @ErrorState);
    RETURN;
END CATCH

-- Final cleanup: ensure database is unsuspended
IF (DATABASEPROPERTYEX(@DatabaseName, 'IsDatabaseSuspendedForSnapshotBackup') = 1)
BEGIN
    ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
    PRINT 'Database unsuspended successfully'
END
    

------------------------------------------------------------
-- Step 7: Review SQL Server error logs to verify operation
------------------------------------------------------------
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc'

GO
