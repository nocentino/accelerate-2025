-- Demo 2b: Retrieving and Managing FlashArray Snapshots via REST (Simplified)
-- Demonstrates SQL Server 2025's ability to query and use existing Pure Storage FlashArray snapshots
--
-- PREREQUISITES:
-- - SQL Server 2025 with 'external rest endpoint enabled'
-- - Valid Pure Storage API token with Storage Admin permissions
-- - Existing protection group snapshots with metadata tags
------------------------------------------------------------

-- Configuration
DECLARE @SqlInstance NVARCHAR(128) = N'aen-sql-25-a';
DECLARE @Database    NVARCHAR(128) = N'TPCC-4T';

-- Working variables  
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(MAX), @Headers NVARCHAR(MAX);

BEGIN TRY
    ------------------------------------------------------------
    -- Authenticate and get session token
    ------------------------------------------------------------
    PRINT 'Authenticating with Pure Storage...'
    
    EXEC @ret = sp_invoke_external_rest_endpoint
         @url = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/login',
         @headers = N'{"api-token":"6a20f30a-2c4b-90eb-ada3-bcae602637a8"}',
         @response = @response OUTPUT;

    IF (@ret <> 0) THROW 50001, 'Authentication failed', 1;

    SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"');
    IF (@AuthToken IS NULL) THROW 50002, 'Failed to extract auth token', 1;
    
    SET @Headers = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}';
    PRINT 'Authentication successful'
    ------------------------------------------------------------
    -- Query snapshots for the specified database
    ------------------------------------------------------------
    PRINT 'Querying snapshots for database: ' + @Database
    
 -- Build filtered query URL
    DECLARE @TagFilter  NVARCHAR(MAX) = N'?filter=tags(''default'',''SQLInstanceName'')=''' + @SqlInstance + ''' and tags(''default'',''DatabaseName'')=''' + @Database + '''&sort=created-';
    DECLARE @FullUrl    NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots' + @TagFilter;

    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @FullUrl,
        @headers = @Headers,
        @method = N'GET', 
        @response = @response OUTPUT;

    IF (@ret <> 0) THROW 50003, 'Failed to retrieve snapshots', 1;
    IF (JSON_VALUE(@response, '$.result.items[0].name') IS NULL) THROW 50004, 'No snapshots found', 1;

    ------------------------------------------------------------
    -- Get snapshot details and extract backup URL
    ------------------------------------------------------------
    DECLARE @SnapshotName NVARCHAR(255) = JSON_VALUE(@response, '$.result.items[0].name');
    IF (@SnapshotName IS NULL) THROW 50005, 'Failed to extract snapshot name', 1;
    
    PRINT 'Most recent snapshot: ' + @SnapshotName;

    DECLARE @TagsUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-27.puretec.purestorage.com/api/2.44/protection-group-snapshots/tags?resource_names=' + @SnapshotName;
    
    EXEC @ret = sp_invoke_external_rest_endpoint
        @url = @TagsUrl,
        @headers = @Headers,
        @method = N'GET',
        @response = @response OUTPUT;
        
    IF (@ret <> 0) THROW 50006, 'Failed to retrieve snapshot tags', 1;
    IF (JSON_QUERY(@response, '$.result.items') IS NULL) THROW 50007, 'No tags found', 1;

    ------------------------------------------------------------
    -- Display snapshot metadata and read backup header
    ------------------------------------------------------------
    PRINT 'Snapshot metadata:'
    
    -- Extract and display key tag values
    DECLARE @BackupUrl NVARCHAR(512);
    SELECT @BackupUrl = JSON_VALUE(item.value, '$.value')
    FROM OPENJSON(@response, '$.result.items') AS item
    WHERE JSON_VALUE(item.value, '$.key') = 'BackupUrl';

    IF (@BackupUrl IS NULL) THROW 50008, 'BackupUrl not found in snapshot tags', 1;

    -- Display tag information in a simplified format
    SELECT 
        JSON_VALUE(item.value, '$.key') AS TagKey,
        JSON_VALUE(item.value, '$.value') AS TagValue
    FROM OPENJSON(@response, '$.result.items') AS item
    WHERE JSON_VALUE(item.value, '$.key') IN ('DatabaseName', 'SQLInstanceName', 'BackupTimestamp', 'BackupType', 'BackupUrl');

    PRINT 'Reading backup header from: ' + @BackupUrl;
    
    RESTORE HEADERONLY FROM URL = @BackupUrl;
    PRINT 'Backup header read successfully'

END TRY
BEGIN CATCH
    PRINT 'Error: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO