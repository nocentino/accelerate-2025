-- Demo 3: Combine FlashArray, DMVs, and perfmon performance data
-- This demo showcases SQL Server 2025's ability to correlate Pure Storage metrics with SQL Server performance data
------------------------------------------------------------
-- Step 1: Initialize variables and authenticate with Pure Storage FlashArray
------------------------------------------------------------
DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(100), @MyHeaders NVARCHAR(1000);
DECLARE @VolumeName NVARCHAR(100) = 'vvol-aen-sql-25-a-1e763fbf-vg/Data-acc37bc2';

/*
    Using an API token with read permissions, connect to the array to log in.
    This login call will return an x-auth-token which is used for authentication with subsequent API calls.
    Pure Storage's authentication process is simple yet secure, enabling easy programmatic access.
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/login',
    @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',
    @response = @response OUTPUT;

------------------------------------------------------------
-- Step 2: Check login status and extract authentication token
------------------------------------------------------------
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

------------------------------------------------------------
-- Step 3: Retrieve Pure Storage volume performance metrics
------------------------------------------------------------
/*
    Get performance metrics for the specified volume using Pure Storage's comprehensive REST API.
    Pure Storage provides granular, real-time performance data with sub-millisecond precision,
    enabling deep insight into storage behavior without additional monitoring tools.
*/
DECLARE @FullUrl NVARCHAR(MAX) = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/volumes/performance?names=' + REPLACE(@VolumeName, '/', '%2F');
  
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = @FullUrl,
    @headers = @MyHeaders,
    @method = N'GET',  -- Explicitly specify the GET method
    @response = @response OUTPUT;

------------------------------------------------------------
-- Step 4: Process and display Pure Storage performance data
------------------------------------------------------------
-- Check if performance data retrieval was successful
IF (@ret <> 0)
BEGIN
    PRINT 'Error retrieving volume performance data: ' + CAST(@ret AS NVARCHAR(10));
    PRINT 'Response: ' + @response;
    RETURN
END

PRINT 'Successfully retrieved volume performance data';

/*
    Extract and display key performance metrics from Pure Storage.
    Pure Storage's detailed metrics include IOPS, bandwidth, and latency data,
    providing visibility into storage performance that traditional monitoring cannot match.
*/
SELECT 
    JSON_VALUE(@response, '$.result.items[0].time') AS sample_time,    
    JSON_VALUE(@response, '$.result.items[0].name') AS volume_name,
    
    -- IOPS metrics - Pure Storage tracks reads and writes separately for more granular analysis
    JSON_VALUE(@response, '$.result.items[0].reads_per_sec') AS reads_per_sec,
    JSON_VALUE(@response, '$.result.items[0].writes_per_sec') AS writes_per_sec,
    
    -- Bandwidth metrics - Pure Storage provides precise throughput measurements
    JSON_VALUE(@response, '$.result.items[0].read_bytes_per_sec') AS read_bytes_per_sec,
    JSON_VALUE(@response, '$.result.items[0].write_bytes_per_sec') AS write_bytes_per_sec,
    
    -- Latency metrics - Pure's industry-leading low latency is measurable in microseconds
    JSON_VALUE(@response, '$.result.items[0].usec_per_read_op') AS read_latency_usec,
    JSON_VALUE(@response, '$.result.items[0].usec_per_write_op') AS write_latency_usec,
    
    -- I/O size metrics - Useful for workload characterization
    JSON_VALUE(@response, '$.result.items[0].bytes_per_read') AS bytes_per_read,
    JSON_VALUE(@response, '$.result.items[0].bytes_per_write') AS bytes_per_write,
    JSON_VALUE(@response, '$.result.items[0].bytes_per_op') AS bytes_per_op;

------------------------------------------------------------
-- Step 5: Compare with SQL Server's performance counters
------------------------------------------------------------
/*
    Query SQL Server's performance counters to correlate with Pure Storage metrics.
    The ability to correlate SQL Server's view of storage with Pure Storage's direct metrics
    provides unprecedented insight for performance tuning and troubleshooting.
    
    Pure Storage's consistently low latency often reveals that performance bottlenecks
    exist elsewhere in the stack, not at the storage layer.
*/

-- Aggregate I/O statistics by storage volume for user databases only
SELECT 
    -- Extract volume information (drive letter/mount point)
    LEFT(mf.physical_name, 1) AS VolumeLetter,
    
    -- Calculate aggregated latencies by volume
    CASE 
        WHEN SUM(vfs.num_of_reads) > 0 THEN SUM(vfs.io_stall_read_ms) * 1.0 / SUM(vfs.num_of_reads)
        ELSE NULL
    END AS AvgReadLatencyMS,
    
    CASE 
        WHEN SUM(vfs.num_of_writes) > 0 THEN SUM(vfs.io_stall_write_ms) * 1.0 / SUM(vfs.num_of_writes)
        ELSE NULL
    END AS AvgWriteLatencyMS,
    
    CASE 
        WHEN (SUM(vfs.num_of_reads) + SUM(vfs.num_of_writes)) > 0 
        THEN (SUM(vfs.io_stall_read_ms) + SUM(vfs.io_stall_write_ms)) * 1.0 / 
             (SUM(vfs.num_of_reads) + SUM(vfs.num_of_writes))
        ELSE NULL
    END AS AvgOverallLatencyMS
FROM 
    sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
JOIN 
    sys.master_files AS mf ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id
JOIN
    sys.databases d ON vfs.database_id = d.database_id
WHERE
    d.database_id > 4 -- Skip system databases by ID
    AND d.name NOT IN ('master', 'model', 'msdb', 'tempdb') -- Explicit exclusion
    AND d.is_distributor = 0  -- Skip distributor database
    AND d.source_database_id IS NULL  -- Skip database snapshots
GROUP BY 
    LEFT(mf.physical_name, 1) -- Group by volume
ORDER BY 
    -- Order volumes by overall latency to highlight potential issues
    AvgOverallLatencyMS DESC;