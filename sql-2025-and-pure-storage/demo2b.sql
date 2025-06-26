-- Demo 2b: Retrieving and Managing FlashArray Snapshots via REST
-- This demo showcases SQL Server 2025's ability to query and use existing Pure Storage FlashArray snapshots
-- This is not a production script, but rather a demonstration of the capabilities of SQL Server 2025 and Pure Storage FlashArray integration.
/*
PREREQUISITES:
- SQL Server 2025 or later
- 'external rest endpoint enabled' server configuration option
- Valid API token with at least 'Storage Admin' permissions on the Pure Storage FlashArray
- Protection group snapshots already existing on the Pure Storage array
- Metadata-only backups previously created for the snapshots
*/

------------------------------------------------------------
-- Step 1: Get a listing of all snapshots in the protection group by database names
------------------------------------------------------------

-- Increase variable sizes to handle larger tokens and responses
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(MAX), @MyHeaders NVARCHAR(MAX);
DECLARE @ErrorMessage NVARCHAR(MAX);

BEGIN TRY
    /*
        Using an API token with read/write permissions in the array, connect to the array to log in.
        This login call will return an x-auth-token which is used for the duration of your session with the array as the authentication token.
        Pure Storage's RESTful API enables seamless integration with SQL Server for automated operations.
    */
    EXEC @ret = sp_invoke_external_rest_endpoint
         @url = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/login',
         @headers = N'{"api-token":"6a20f30a-2c4b-90eb-ada3-bcae602637a8"}',
         @response = @response OUTPUT;

    PRINT 'Login Return Code: ' + CAST(@ret AS NVARCHAR(10))
    
    -- Check for login success
    IF (@ret <> 0)
    BEGIN
        SET @ErrorMessage = 'Error in REST call, unable to login to the array. Return code: ' + CAST(@ret AS NVARCHAR(10))
        RAISERROR(@ErrorMessage, 16, 1)
        RETURN
    END

    ------------------------------------------------------------
    -- Step 2: Extract authentication token for subsequent operations
    ------------------------------------------------------------
    /*
        First, read the x-auth-token from the login response from the array
        Then, build the header to be passed into the next REST call in the array.
        Pure's token-based authentication enables secure automation.
    */
    SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"');
    
    -- Verify token extraction was successful
    IF (@AuthToken IS NULL)
    BEGIN
        RAISERROR('Failed to extract authentication token from response', 16, 1)
        RETURN
    END
    
    SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}'

    /*
        Query snapshots filtered by SQL instance and database name via the Pure Storage REST API.
        Pure Storage's rich tagging system enables precise filtering and management of snapshots
        across large environments, making it easy to find relevant backups.
    */
    DECLARE @ProtectionGroup NVARCHAR(255) = 'aen-sql-25-a-pg';
    DECLARE @APIEndpoint     NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots';
    DECLARE @TagFilter       NVARCHAR(MAX) = N'?filter=tags(''default'',''SQLInstanceName'')=''aen-sql-25-a'' and tags(''default'',''DatabaseName'')=''TPCC-4T''&sort=created-';
    DECLARE @FullUrl         NVARCHAR(MAX) = @APIEndpoint + @TagFilter;
    
    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @FullUrl,
        @headers = @MyHeaders,
        @method = N'GET', 
        @response = @response OUTPUT;
        
    -- Check for successful API call
    IF (@ret <> 0)
    BEGIN
        SET @ErrorMessage = 'Error retrieving snapshots. Return code: ' + CAST(@ret AS NVARCHAR(10))
        RAISERROR(@ErrorMessage, 16, 1)
        RETURN
    END

    -- Check if we have valid results in the response
    IF (JSON_VALUE(@response, '$.result.total_item_count') = '0' OR JSON_VALUE(@response, '$.result.items[0].name') IS NULL)
    BEGIN
        RAISERROR('No matching snapshots found with the specified criteria', 16, 1)
        RETURN
    END

    /*
        Extract the most recent snapshot name from the response.
        Pure Storage's well-structured JSON API enables simple extraction of 
        snapshot metadata using SQL Server's built-in JSON functions.
    */
    DECLARE @MostRecentSnapshotName NVARCHAR(255);
    SET @MostRecentSnapshotName = JSON_VALUE(@response, '$.result.items[0].name');
    
    IF (@MostRecentSnapshotName IS NULL)
    BEGIN
        RAISERROR('Failed to extract snapshot name from response', 16, 1)
        RETURN
    END
    
    PRINT 'Most Recent Snapshot Name: ' + @MostRecentSnapshotName;

    /*
        Retrieve detailed tag information for the selected snapshot.
        Pure Storage's comprehensive tagging system allows SQL Server to maintain
        a complete record of backup details without needing additional tables or tracking.
    */
    DECLARE @SnapshotUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots/tags?resource_names=' + @MostRecentSnapshotName;
    
    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @SnapshotUrl,
        @headers = @MyHeaders,
        @method = N'GET',
        @response = @response OUTPUT;
        
    -- Check for successful API call
    IF (@ret <> 0)
    BEGIN
        SET @ErrorMessage = 'Error retrieving snapshot tags. Return code: ' + CAST(@ret AS NVARCHAR(10))
        RAISERROR(@ErrorMessage, 16, 1)
        RETURN
    END

    -- Check if response contains items
    IF (JSON_QUERY(@response, '$.result.items') IS NULL)
    BEGIN
        RAISERROR('No tags found for the specified snapshot', 16, 1)
        RETURN
    END

    /*
        Parse the snapshot tags response to show all tag information.
        Pure Storage's comprehensive tagging system provides rich metadata
        for each snapshot, enabling advanced filtering and management.
    */
    DECLARE @items NVARCHAR(MAX) = JSON_QUERY(@response, '$.result.items');

    -- Display tags in a pivoted format
    WITH Flattened AS (
        SELECT 
            JSON_VALUE(item.value, '$.context.name') AS ContextName,
            JSON_VALUE(item.value, '$.namespace') AS Namespace,
            JSON_VALUE(item.value, '$.resource.name') AS ResourceName,
            JSON_VALUE(item.value, '$.resource.id') AS ResourceId,
            JSON_VALUE(item.value, '$.key') AS TagKey,
            JSON_VALUE(item.value, '$.value') AS TagValue,
            JSON_VALUE(item.value, '$.copyable') AS Copyable
        FROM OPENJSON(@items) AS item
    )
    SELECT *
    FROM (
        SELECT *
        FROM Flattened
    ) AS SourceTable
    PIVOT (
        MAX(TagValue)
        FOR TagKey IN (
            [DatabaseName],
            [SQLInstanceName],
            [BackupTimestamp],
            [BackupType],
            [BackupUrl]
        )
    ) AS PivotTable;

    /*
        Extract the backup URL from the snapshot tags.
        Pure Storage's tag-based metadata enables seamless integration between
        the storage snapshot and SQL Server's metadata-only backup file.
    */
    DECLARE @SnapshotBackupUrl NVARCHAR(512);

    -- Extract the backup URL in a simpler way
    SELECT @SnapshotBackupUrl = JSON_VALUE(item.value, '$.value')
    FROM OPENJSON(@response, '$.result.items') AS item
    WHERE JSON_VALUE(item.value, '$.key') = 'BackupUrl';

    -- Check if backup URL was found
    IF (@SnapshotBackupUrl IS NULL)
    BEGIN
        RAISERROR('BackupUrl tag not found for the specified snapshot', 16, 1)
        RETURN
    END

    PRINT 'Backup URL: ' + @SnapshotBackupUrl;

    ------------------------------------------------------------
    -- Step 3: Verify backup metadata by reading backup header
    ------------------------------------------------------------
    /*
        Read the backup header from the metadata-only backup file.
        This completes the integration between Pure Storage snapshots and 
        SQL Server's native backup catalog, enabling standard backup management
        tools to work seamlessly with Pure's high-performance snapshots.
    */
    PRINT 'Reading backup header from: ' + @SnapshotBackupUrl;
    
    -- Use TRY/CATCH for RESTORE operation
    BEGIN TRY
        RESTORE HEADERONLY FROM URL = @SnapshotBackupUrl;
    END TRY
    BEGIN CATCH
        SET @ErrorMessage = 'Error reading backup header: ' + ERROR_MESSAGE()
        RAISERROR(@ErrorMessage, 16, 1)
    END CATCH

END TRY
BEGIN CATCH
    SET @ErrorMessage = ERROR_MESSAGE()
    PRINT 'Error: ' + @ErrorMessage
END CATCH
GO