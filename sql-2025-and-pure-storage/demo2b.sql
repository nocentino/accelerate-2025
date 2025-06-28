-- Demo 2b: Retrieving and Managing FlashArray Snapshots via REST (Improved & Simplified)
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
-- Step 1: Configuration and Authentication
------------------------------------------------------------
-- Configuration variables (customize these for your environment)
DECLARE @ArrayUrl        NVARCHAR(255) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44'; -- Pure Storage API URL
DECLARE @ApiToken        NVARCHAR(255) = N'6a20f30a-2c4b-90eb-ada3-bcae602637a8'; -- Store securely in production
DECLARE @ProtectionGroup NVARCHAR(255) = N'aen-sql-25-a-pg';
DECLARE @InstanceFilter  NVARCHAR(128) = N'aen-sql-25-a';
DECLARE @DatabaseFilter  NVARCHAR(128) = N'TPCC-4T';

-- Working variables
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(MAX), @MyHeaders NVARCHAR(MAX);

BEGIN TRY
    PRINT 'Authenticating with Pure Storage FlashArray...'
    
    EXEC @ret = sp_invoke_external_rest_endpoint
         @url = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/login',
         @headers = N'{"api-token":"6a20f30a-2c4b-90eb-ada3-bcae602637a8"}',
         @response = @response OUTPUT;

    IF (@ret <> 0)
        THROW 50001, 'Failed to authenticate with Pure Storage array', 1;
    
    PRINT 'Authentication successful'

    ------------------------------------------------------------
    -- Step 2: Extract authentication token and query snapshots
    ------------------------------------------------------------
    SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"');
    
    IF (@AuthToken IS NULL)
        THROW 50002, 'Failed to extract authentication token from response', 1;
    
    SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}'

    PRINT 'Querying snapshots for database: ' + @DatabaseFilter
    
    -- Build filtered query URL
    DECLARE @TagFilter  NVARCHAR(MAX) = N'?filter=tags(''default'',''SQLInstanceName'')=''' + @InstanceFilter + ''' and tags(''default'',''DatabaseName'')=''' + @DatabaseFilter + '''&sort=created-';
    DECLARE @FullUrl    NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots' + @TagFilter;

    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @FullUrl,
        @headers = @MyHeaders,
        @method = N'GET', 
        @response = @response OUTPUT;

    IF (@ret <> 0)
        THROW 50003, 'Failed to retrieve snapshots from Pure Storage array', 1;

    -- Verify we have results
    IF (JSON_VALUE(@response, '$.result.total_item_count') = '0' OR JSON_VALUE(@response, '$.result.items[0].name') IS NULL)
        THROW 50004, 'No matching snapshots found with the specified criteria', 1;

    ------------------------------------------------------------
    -- Step 3: Extract most recent snapshot and get detailed tags
    ------------------------------------------------------------
    DECLARE @MostRecentSnapshotName NVARCHAR(255) = JSON_VALUE(@response, '$.result.items[0].name');
    
    IF (@MostRecentSnapshotName IS NULL)
        THROW 50005, 'Failed to extract snapshot name from response', 1;
    
    PRINT 'Most Recent Snapshot: ' + @MostRecentSnapshotName;

    -- Get detailed tag information for the snapshot
    DECLARE @SnapshotUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots/tags?resource_names=' + @MostRecentSnapshotName;
    
    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @SnapshotUrl,
        @headers = @MyHeaders,
        @method = N'GET',
        @response = @response OUTPUT;
        
    IF (@ret <> 0)
        THROW 50006, 'Failed to retrieve snapshot tags from Pure Storage array', 1;

    IF (JSON_QUERY(@response, '$.result.items') IS NULL)
        THROW 50007, 'No tags found for the specified snapshot', 1;

    ------------------------------------------------------------
    -- Step 4: Display snapshot tags and extract backup URL
    ------------------------------------------------------------
    PRINT 'Snapshot tag information:'
    
    -- Parse and display tags in a pivoted format
    DECLARE @items NVARCHAR(MAX) = JSON_QUERY(@response, '$.result.items');

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

    -- Extract the backup URL from the snapshot tags
    DECLARE @SnapshotBackupUrl NVARCHAR(512);

    SELECT @SnapshotBackupUrl = JSON_VALUE(item.value, '$.value')
    FROM OPENJSON(@response, '$.result.items') AS item
    WHERE JSON_VALUE(item.value, '$.key') = 'BackupUrl';

    IF (@SnapshotBackupUrl IS NULL)
        THROW 50008, 'BackupUrl tag not found for the specified snapshot', 1;

    PRINT 'Backup URL: ' + @SnapshotBackupUrl;

    ------------------------------------------------------------
    -- Step 5: Verify backup metadata by reading backup header
    ------------------------------------------------------------
    PRINT 'Reading backup header from: ' + @SnapshotBackupUrl;
    
    BEGIN TRY
        RESTORE HEADERONLY FROM URL = @SnapshotBackupUrl;
        PRINT 'Backup header read successfully'
    END TRY
    BEGIN CATCH
        DECLARE @BackupError NVARCHAR(4000) = 'Error reading backup header: ' + ERROR_MESSAGE();
        THROW 50009, @BackupError, 1;
    END CATCH

END TRY
BEGIN CATCH
    DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
    DECLARE @ErrorState INT = ERROR_STATE();
    
    PRINT 'Error occurred: ' + @ErrorMsg
    RAISERROR(@ErrorMsg, @ErrorSeverity, @ErrorState);
END CATCH
GO