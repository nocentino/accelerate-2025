-- Demo 3 - Using change events to drive AI outcomes
-- This demo showcases SQL Server's Change Tracking feature with Pure Storage's
-- high-performance infrastructure to efficiently maintain AI embeddings
------------------------------------------------------------
-- Step 1: Enable Change Tracking on the database and table
------------------------------------------------------------
/*
    First, enable Change Tracking at the database level with a 2-day retention period.
    Pure Storage's consistent performance ensures that Change Tracking operations
    have minimal impact on overall system workload. Pure Storage's data reduction 
    capabilities also minimize the storage overhead typically associated with 
    change tracking metadata.
*/
ALTER DATABASE StackOverflow_Embeddings
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO

USE StackOverflow_Embeddings;
GO

/*
    Enable Change Tracking on the Posts table with column tracking.
    Pure Storage's high IOPS capabilities ensure tracking additional
    change metadata doesn't impact transaction performance.
*/
ALTER TABLE dbo.Posts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO

------------------------------------------------------------
-- Step 2: Retrieve a sample row to modify for demonstration
------------------------------------------------------------
/*
    Select a sample row to modify for our change tracking demonstration.
    Pure Storage's low latency ensures consistent query performance even when
    joining tables with complex data types like vector embeddings.
*/
SELECT TOP 1 
    p.Id, 
    p.Body, 
    pe.Embedding, 
    pe.CreatedAt, 
    pe.UpdatedAt 
FROM 
    dbo.Posts AS p
INNER JOIN 
    dbo.PostEmbeddings AS pe 
ON 
    p.Id = pe.PostID;
GO

------------------------------------------------------------
-- Step 3: Update a post to trigger Change Tracking
------------------------------------------------------------
/*
    Update a single post, which will be tracked by Change Tracking.
    Pure Storage's write performance ensures updates complete rapidly,
    even when change tracking metadata is being captured simultaneously.
*/
UPDATE dbo.Posts
SET 
    Body = '<p>I want to assign the decimal variable &quot;trans&quot; to the float variable &quot;this.Opacity&quot;.</p>',
    Title = 'Updated Post Title'
WHERE 
    Id = 4;
GO

------------------------------------------------------------
-- Step 4: Create a stored procedure to process changes and update embeddings
------------------------------------------------------------
/*
    This stored procedure uses Change Tracking to identify modified rows,
    then automatically generates new AI embeddings for those changes.
    Pure Storage's performance enables AI-driven operations to run
    efficiently alongside transactional workloads without impacting users.
*/
CREATE OR ALTER PROCEDURE dbo.UpdatePostEmbeddings
AS
BEGIN
    SET NOCOUNT ON;

    -- Get the last synchronization version
    DECLARE @LastSyncVersion BIGINT = ISNULL(
        (SELECT MAX(SyncVersion) FROM dbo.PostEmbeddingsSyncLog),
        0
    );

    -- Get the current version
    DECLARE @CurrentVersion BIGINT = CHANGE_TRACKING_CURRENT_VERSION();

    /*
        Process newly inserted rows.
        Pure Storage's efficient data handling enables simultaneous reading of 
        change data and writing of new embedding vectors without I/O bottlenecks.
    */
    INSERT INTO dbo.PostEmbeddings (PostID, Embedding, CreatedAt)
    SELECT 
        p.Id,
        AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama) AS Embedding, -- Generate embeddings
        GETDATE() AS CreatedAt
    FROM 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
    JOIN 
        dbo.Posts p ON ct.Id = p.Id
    WHERE 
        ct.SYS_CHANGE_OPERATION IN ('I') -- Inserted rows
        AND NOT EXISTS (
            SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.Id
        );

    /*
        Update embeddings for modified rows.
        Pure Storage's consistent low latency ensures the AI model can quickly
        process updates without creating a backlog of pending changes.
    */
    UPDATE pe
    SET 
        pe.Embedding = AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama),
        pe.UpdatedAt = GETDATE()
    FROM 
        dbo.PostEmbeddings pe
    JOIN 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
        ON pe.PostID = ct.Id
    JOIN 
        dbo.Posts p ON ct.Id = p.Id
    WHERE 
        ct.SYS_CHANGE_OPERATION = 'U'; -- Updated rows

    -- Log the synchronization version
    INSERT INTO dbo.PostEmbeddingsSyncLog (SyncVersion, SyncTime)
    VALUES (@CurrentVersion, GETDATE());
END;
GO

------------------------------------------------------------
-- Step 5: Create tracking table for synchronization versions
------------------------------------------------------------
/*
    Create a table to track synchronization versions.
    Pure Storage's reliable performance ensures version tracking
    remains consistent even under heavy transactional loads.
*/
CREATE TABLE dbo.PostEmbeddingsSyncLog (
    SyncVersion BIGINT PRIMARY KEY,
    SyncTime DATETIME NOT NULL
);
GO

------------------------------------------------------------
-- Step 6: Execute the procedure and verify results
------------------------------------------------------------
/*
    Execute the procedure to process changes and update embeddings.
    Pure Storage's high throughput ensures AI processing completes quickly,
    enabling near-real-time semantic search on newly updated content.
*/
EXEC dbo.UpdatePostEmbeddings;

-- Check the synchronization log
SELECT * FROM dbo.PostEmbeddingsSyncLog

/*
    Verify that the embedding for the modified post has been updated.
    Pure Storage's performance enables immediate verification of changes,
    ensuring data consistency between operational and AI systems.
*/
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings
WHERE PostID = 4;