-- Demo 3 - Combine FlashArray, DVMs, and perfmon performance data

DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(100), @MyHeaders NVARCHAR(1000);
DECLARE @VolumeName NVARCHAR(100) = 'vvol-aen-sql-25-a-1e763fbf-vg/Data-acc37bc2';

/*
    Using an API token with read permissions, connect to the array to log in.
    This login call will return an x-auth-token which is used for authentication with subsequent API calls.
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/login',
    @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',
    @response = @response OUTPUT;

-- Check if login was successful
IF (@ret <> 0)
BEGIN
    PRINT 'Error in REST call, unable to login to the array.'
    RETURN
END

-- Extract auth token from login response
SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"');
SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}';

PRINT 'Successfully logged in to FlashArray';

/*
    Get performance metrics for the specified volume
    URL encoding the volume name since it contains a forward slash
*/

DECLARE @FullUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/volumes/performance?names=' + REPLACE(@VolumeName, '/', '%2F');
  
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = @FullUrl,
    @headers = @MyHeaders,
    @method = N'GET',  -- Explicitly specify the GET method
    @response = @response OUTPUT;

-- Check if performance data retrieval was successful
IF (@ret <> 0)
BEGIN
    PRINT 'Error retrieving volume performance data: ' + CAST(@ret AS NVARCHAR(10));
    PRINT 'Response: ' + @response;
    RETURN
END

PRINT 'Successfully retrieved volume performance data';

-- Extract and display key performance metrics
-- Extract and display all available performance metrics
-- Extract and display performance metrics based on actual JSON structure
SELECT 
    JSON_VALUE(@response, '$.result.items[0].time') AS sample_time,    
    JSON_VALUE(@response, '$.result.items[0].name') AS volume_name,
    
    -- IOPS metrics
    JSON_VALUE(@response, '$.result.items[0].reads_per_sec') AS reads_per_sec,
    JSON_VALUE(@response, '$.result.items[0].writes_per_sec') AS writes_per_sec,
    
    -- Bandwidth metrics
    JSON_VALUE(@response, '$.result.items[0].read_bytes_per_sec') AS read_bytes_per_sec,
    JSON_VALUE(@response, '$.result.items[0].write_bytes_per_sec') AS write_bytes_per_sec,
    
    -- Latency metrics
    JSON_VALUE(@response, '$.result.items[0].usec_per_read_op') AS read_latency_usec,
    JSON_VALUE(@response, '$.result.items[0].usec_per_write_op') AS write_latency_usec,
    
    -- I/O size metrics
    JSON_VALUE(@response, '$.result.items[0].bytes_per_read') AS bytes_per_read,
    JSON_VALUE(@response, '$.result.items[0].bytes_per_write') AS bytes_per_write,
    JSON_VALUE(@response, '$.result.items[0].bytes_per_op') AS bytes_per_op


EXEC xp_fixeddrives;

