-- Demo 2 - Using REST to take FlashArray snapshots


--Enable REST endpoint
sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;



DECLARE @ret INT, @response NVARCHAR(MAX), @AuthToken NVARCHAR(100), @MyHeaders NVARCHAR(100);

/*
    Using an API token with read/write permissions in the array, connect to the array to log in.
    This login call will return an x-auth-token which is used for the duration of your session with the array as the authentication token
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/login',
    @headers = N'{"api-token":"3b078aa4-94a8-68da-8e7b-04aec357f678"}',
    @response = @response OUTPUT;


PRINT 'Login Return Code: ' + CAST(@ret AS NVARCHAR(10))
PRINT 'Login Response: ' + @response

/*
    If the return code from the array is not 0, print an error message and return.
*/
if ( @ret <> 0 )
    BEGIN
        PRINT 'Error in REST call, unable to login to the array.'
        RETURN
    END

/*
    First, read the x-auth-token from the login response from the array
    Then, build the header to be passed into the next REST call in the array
*/
SET @AuthToken = JSON_VALUE(@response, '$.response.headers."x-auth-token"'); --need the double quotes on x-auth-token or else json validation fails when using JSON_VALUE
SET @MyHeaders = N'{"x-auth-token":"' + @AuthToken + '", "Content-Type":"application/json"}'

PRINT 'Headers: ' + @MyHeaders

/*
    First, suspend the database to take a snapshot
*/
ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON


/*
    Next call the REST endpoint to take a snapshot backup of the database.
*/
EXEC @ret = sp_invoke_external_rest_endpoint
    @url = N'https://sn1-x90r2-f06-33.puretec.purestorage.com/api/2.36/protection-group-snapshots',
    @headers = @MyHeaders,
    @payload = N'{"source_names":"aen-sql-25-a-pg"}',    
    @response = @response OUTPUT;

PRINT 'Snapshot Return Code: ' + CAST(@ret AS NVARCHAR(10))
PRINT 'Snapshot Response: ' + @response

/*
    Get the snapshot name from the JSON response from the REST call which will be added to the Backup Media Description.
*/
DECLARE @SnapshotName NVARCHAR(100)
SET @SnapshotName = JSON_VALUE(@response, '$.result.items[0].name')

/*
    If the return code from the array is 0, take the snapshot backup. If not, print an error message and unsuspend the database.
*/
if ( @ret = 0 ) --is using 200 (OK) from @response a better check here?
    BEGIN
        BACKUP DATABASE [TPCC-4T] TO DISK='SnapshotBack.bkm' WITH METADATA_ONLY, MEDIADESCRIPTION=@SnapshotName
        PRINT 'Snapshot backup successful. Snapshot Name: ' + @SnapshotName
    END
ELSE 
    BEGIN
        ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF
        PRINT 'Error in REST call, snapshot backup failed. Database unsuspended.'
    END


--read the error log in descending order
EXEC xp_readerrorlog 0, 1, NULL, NULL, NULL, NULL, N'desc'

--rollover the errorlog 
EXEC sp_cycle_errorlog

GO


