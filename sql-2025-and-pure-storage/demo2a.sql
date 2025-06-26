-- Demo 2: Using REST to take FlashArray snapshots
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
-- Step 2: Initialize variables and authenticate with Pure Storage FlashArray
------------------------------------------------------------
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(MAX), @MyHeaders NVARCHAR(MAX);
DECLARE @SnapshotName NVARCHAR(255); -- Increased size for safety
DECLARE @ErrorMessage NVARCHAR(MAX);

BEGIN TRY
    /*
        Using an API token with read/write permissions in the array, connect to the array to log in.
        This login call will return an x-auth-token which is used for the duration of your session with the array as the authentication token.
        Pure Storage's RESTful API enables seamless integration with SQL Server for automated operations.
    */
    EXEC @ret = sp_invoke_external_rest_endpoint
         @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/login',
         @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',         -- In production, API tokens should be stored securely, not hardcoded
         @response = @response OUTPUT;

    PRINT 'Login Return Code: ' + CAST(@ret AS NVARCHAR(10))
    
    -- Check for login success
    IF (@ret <> 0)
    BEGIN
        SET @ErrorMessage = 'Error in REST call, unable to login to the array. Return code: ' + CAST(@ret AS NVARCHAR(10))
        RAISERROR(@ErrorMessage, 16, 1)
        RETURN
    END
    
    PRINT 'Login Response: ' + @response

    ------------------------------------------------------------
    -- Step 3: Extract authentication token for subsequent operations
    ------------------------------------------------------------
    /*
        First, read the x-auth-token from the login response from the array
        Then, build the header to be passed into the next REST call in the array.
        Pure's token-based authentication enables secure automation.
    */
    SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"')
    
    -- Verify token extraction was successful
    IF (@AuthToken IS NULL)
    BEGIN
        RAISERROR('Failed to extract authentication token from response', 16, 1)
        RETURN
    END
    
    SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}' 
    PRINT 'Headers: ' + @MyHeaders

    ------------------------------------------------------------
    -- Step 4: Prepare database for snapshot using SQL Server's snapshot backup feature
    ------------------------------------------------------------
    /*
        First, suspend the database for write IO only to take a snapshot.
        SQL Server's SUSPEND_FOR_SNAPSHOT_BACKUP feature works seamlessly with Pure Storage's
        snapshot technology to create application-consistent snapshots with minimal disruption, usually around 10-20 milliseconds.
    */
    ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON

    ------------------------------------------------------------
    -- Step 5: Create storage-level Protection Group snapshot using Pure Storage FlashArray
    ------------------------------------------------------------
    /*
        Next call the REST endpoint to take a snapshot backup of the database.
        Pure Storage snapshots are instantaneous, space-efficient (only storing changes),
        and have zero performance impact - ideal for production database environments.

        Add metadata tags to the snapshot for easy identification and management to the Pure Storage Protection Group Snapshot.

        In this example, we are using a Protection Group named 'aen-sql-25-a-pg' which is already configured on the Pure Storage array.

        We are also replicating the snapshot immediately by setting "replicate_now" to true to another array.
    */
    -- Generate dynamic filename with instance name, database name, backup type and date
    DECLARE @InstanceName   NVARCHAR(128) = REPLACE(@@SERVERNAME, '\', '_');
    DECLARE @DatabaseName   NVARCHAR(128) = 'TPCC-4T';
    DECLARE @BackupType     NVARCHAR(20)  = 'SNAPSHOT';
    DECLARE @DateStamp      NVARCHAR(20)  = REPLACE(CONVERT(NVARCHAR, GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR, GETDATE(), 108), ':', ''), ' ', '_');
    DECLARE @BackupFileName NVARCHAR(255) = @InstanceName + '_' + @DatabaseName + '_' + @BackupType + '_' + @DateStamp + '.bkm';
    DECLARE @BackupUrl      NVARCHAR(512) = 's3://s200.fsa.lab/aen-sql-backups/' + @BackupFileName;
    DECLARE @Payload        NVARCHAR(MAX);

    -- Build a comprehensive payload with all important backup values
    SET @Payload = N'{  
        "source_names": "aen-sql-25-a-pg",
        "replicate_now": true,
        "tags": [
            {
                "copyable": true,
                "key": "DatabaseName",
                "value": "' + @DatabaseName + '"
            },
            {
                "copyable": true,
                "key": "SQLInstanceName",
                "value": "' + @InstanceName + '"
            },
            {
                "copyable": true,
                "key": "BackupTimestamp",
                "value": "' + @DateStamp + '"
            },
            {
                "copyable": true,
                "key": "BackupType",
                "value": "' + @BackupType + '"
            },
            {
                "copyable": true,
                "key": "BackupUrl",
                "value": "' + @BackupUrl + '"
            }
        ]
    }';

    PRINT 'Payload: ' + @Payload;

    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/protection-group-snapshots',
        @headers = @MyHeaders,
        @payload = @Payload,
        @response = @response OUTPUT;

    PRINT 'Snapshot Return Code: ' + CAST(@ret AS NVARCHAR(10))
    PRINT 'Snapshot Response: ' + @response

    ------------------------------------------------------------
    -- Step 6: Create metadata-only backup referencing the Pure Storage snapshot
    ------------------------------------------------------------
    /*
        Get the snapshot name from the JSON response from the REST call which will be added to the Backup Media Description.
        Pure Storage snapshots are uniquely identified and can be immediately used for recovery or cloning.
    */
    SET @SnapshotName = JSON_VALUE(@response, '$.result.items[0].name')
    
    -- Verify snapshot name extraction was successful
    IF (@SnapshotName IS NULL AND @ret = 0)
    BEGIN
        RAISERROR('Failed to extract snapshot name from response', 16, 1)
        ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
        RETURN
    END

    /*
        If the return code from the array is 0, take the snapshot backup. If not, print an error message and unsuspend the database.
        Pure's integration with SQL Server enables metadata-only backups, reducing traditional backup windows
        from hours to seconds while maintaining full recoverability through the Pure Storage snapshot.
    */
    IF (@ret = 0) -- Success (HTTP 200 OK)
    BEGIN 
        BACKUP DATABASE [TPCC-4T] TO URL = @BackupUrl WITH METADATA_ONLY, MEDIADESCRIPTION = @SnapshotName;
        PRINT 'Snapshot backup successful. Snapshot Name: ' + @SnapshotName
        PRINT 'Backup file created: ' + @BackupUrl
    END
    ELSE 
    BEGIN
        SET @ErrorMessage = 'Error creating snapshot. Return code: ' + CAST(@ret AS NVARCHAR(10)) + ', Response: ' + @response
        RAISERROR(@ErrorMessage, 16, 1)
    END

END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE()
    PRINT 'Error: ' + @ErrorMessage
    ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
    PRINT 'Database unsuspended after unsuccessful operation'
END CATCH


ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
PRINT 'Database unsuspended after successful operation'

------------------------------------------------------------
-- Step 7: Review SQL Server error logs to verify operation
------------------------------------------------------------
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc'

GO
