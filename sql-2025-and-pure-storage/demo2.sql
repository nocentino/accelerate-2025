-- Demo 2: Using REST to take FlashArray snapshots
-- This demo showcases SQL Server 2025's native integration with Pure Storage FlashArray for near-instant snapshots
-- This is not a production script, but rather a demonstration of the capabilities of SQL Server 2025 and Pure Storage FlashArray integration.
/*
PREREQUISITES:
- SQL Server 2025 or later
- 'external rest endpoint enabled' server configuration option
- Valid API token with at least 'Storage Admin' permissions on the Pure Storage FlashArray
- Protection group already configured on the Pure Storage array
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
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(100), @MyHeaders NVARCHAR(100);

/*
    Using an API token with read/write permissions in the array, connect to the array to log in.
    This login call will return an x-auth-token which is used for the duration of your session with the array as the authentication token.
    Pure Storage's RESTful API enables seamless integration with SQL Server for automated operations.
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/login',
    @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',
    @response = @response OUTPUT;

PRINT 'Login Return Code: ' + CAST(@ret AS NVARCHAR(10))
PRINT 'Login Response: ' + @response

/*
    If the return code from the array is not 0, print an error message and return.
    Pure Storage APIs provide clear error responses for simplified troubleshooting.
*/
if ( @ret <> 0 )
    BEGIN
        PRINT 'Error in REST call, unable to login to the array.'
        RETURN
    END

------------------------------------------------------------
-- Step 3: Extract authentication token for subsequent operations
------------------------------------------------------------
/*
    First, read the x-auth-token from the login response from the array
    Then, build the header to be passed into the next REST call in the array.
    Pure's token-based authentication enables secure automation.
*/
SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"'); --need the double quotes on x-auth-token or else json validation fails when using JSON_VALUE
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
-- Step 5: Create storage-level snapshot using Pure Storage FlashArray
------------------------------------------------------------
/*
    Next call the REST endpoint to take a snapshot backup of the database.
    Pure Storage snapshots are instantaneous, space-efficient (only storing changes),
    and have zero performance impact - ideal for production database environments.
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/protection-group-snapshots',
    @headers = @MyHeaders,
    @payload = N'{"source_names":"aen-sql-25-a-pg"}',
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
DECLARE @SnapshotName NVARCHAR(100)
SET @SnapshotName = JSON_VALUE(@response, '$.result.items[0].name')

/*
    If the return code from the array is 0, take the snapshot backup. If not, print an error message and unsuspend the database.
    Pure's integration with SQL Server enables metadata-only backups, reducing traditional backup windows
    from hours to seconds while maintaining full recoverability through the Pure Storage snapshot.
*/

-- Generate dynamic filename with instance name, database name, backup type and date
DECLARE @InstanceName NVARCHAR(128) = REPLACE(@@SERVERNAME, '\', '_');
DECLARE @DatabaseName NVARCHAR(128) = 'TPCC-4T';
DECLARE @BackupType NVARCHAR(20) = 'SNAPSHOT';
DECLARE @DateStamp NVARCHAR(20) = REPLACE(CONVERT(NVARCHAR, GETDATE(), 112) + '_' + REPLACE(CONVERT(NVARCHAR, GETDATE(), 108), ':', ''), ' ', '_');
DECLARE @BackupFileName NVARCHAR(255) = @InstanceName + '_' + @DatabaseName + '_' + @BackupType + '_' + @DateStamp + '.bkm';
DECLARE @BackupUrl NVARCHAR(512) = 's3://s200.fsa.lab/aen-sql-backups/' + @BackupFileName;
PRINT 'Backup File Name: ' + @BackupFileName

if ( @ret = 0 ) --is using 200 (OK) from @response
    BEGIN 
        BACKUP DATABASE [TPCC-4T] TO URL = @BackupUrl WITH METADATA_ONLY, MEDIADESCRIPTION = @SnapshotName;
        PRINT 'Snapshot backup successful. Snapshot Name: ' + @SnapshotName
        PRINT 'Backup file created: ' + @BackupUrl

        -- Update the protection-group-snapshot with comprehensive tags
        DECLARE @TagPayload NVARCHAR(MAX);

        -- Build a comprehensive payload with all important backup values
        SET @TagPayload = N'[
                {
                    "copyable": true,
                    "key": "BackupFileName",
                    "value": "' + @BackupFileName + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                },
                {
                    "copyable": true,
                    "key": "DatabaseName",
                    "value": "' + @DatabaseName + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                },
                {
                    "copyable": true,
                    "key": "SQLInstanceName",
                    "value": "' + @InstanceName + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                },
                {
                    "copyable": true,
                    "key": "BackupTimestamp",
                    "value": "' + @DateStamp + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                },
                {
                    "copyable": true,
                    "key": "BackupType",
                    "value": "' + @BackupType + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                },
                {
                    "copyable": true,
                    "key": "BackupUrl",
                    "value": "' + @BackupUrl + '",
                    "resource": { 
                        "name": "' + @SnapshotName + '"
                    }
                }
            ]';

        PRINT 'Tag Payload: ' + @TagPayload;

        -- Apply the tags to the protection group snapshot
        EXEC @ret = sp_invoke_external_rest_endpoint
        @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/protection-group-snapshots/tags/batch',
        @headers = @MyHeaders,
        @method = N'PUT',  -- Explicitly specify the POST method
        @payload = @TagPayload,
        @response = @response OUTPUT;

        PRINT 'Tag Response: ' + @response;

    END
ELSE 
    BEGIN
        ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
        PRINT 'Error in REST call, snapshot backup failed. Database unsuspended.'
    END


------------------------------------------------------------
-- Step 7: Review SQL Server error logs to verify operation
------------------------------------------------------------
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc'

--https://sn1-x90r2-f06-33.puretec.purestorage.com/protection/protection_groups/protection_group/aen-sql-25-a-pg

--rollover the errorlog 
EXEC sp_cycle_errorlog


------------------------------------------------------------
-- Step 8: Get a listing of all snapshots in the protection group by database names
------------------------------------------------------------
DECLARE @ProtectionGroup NVARCHAR(100) = 'aen-sql-25-a-pg';
DECLARE @FullUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.44/protection-group-snapshots?filter=tags(''default'',''SQLInstanceName'')=''aen-sql-25-a'' and tags(''default'',''DatabaseName'')=''TPCC-4T''';
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = @FullUrl,
    @headers = @MyHeaders,
    @method = N'GET',  -- Explicitly specify the GET method
    @response = @response OUTPUT;

PRINT 'Tag Response: ' + @response;