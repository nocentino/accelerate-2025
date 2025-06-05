-- Demo 3 - Using change events to drive AI outcomes
-- Enable Change Tracking on the database
ALTER DATABASE StackOverflow
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO

-- Enable Change Tracking on the Posts table
ALTER TABLE dbo.Posts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO


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

    -- Process inserted or updated rows
    INSERT INTO dbo.PostEmbeddings (PostID, Embeddings, CreatedAt)
    SELECT 
        p.PostID,
        AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama) AS Embeddings, -- Generate embeddings
        GETDATE() AS CreatedAt
    FROM 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
    JOIN 
        dbo.Posts p ON ct.PostID = p.PostID
    WHERE 
        ct.SYS_CHANGE_OPERATION IN ('I', 'U') -- Inserted or updated rows
        AND NOT EXISTS (
            SELECT 1 FROM dbo.PostEmbeddings pe WHERE pe.PostID = p.PostID
        );

    -- Update embeddings for modified rows
    UPDATE pe
    SET 
        pe.Embeddings = AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama),
        pe.UpdatedAt = GETDATE()
    FROM 
        dbo.PostEmbeddings pe
    JOIN 
        CHANGETABLE(CHANGES dbo.Posts, @LastSyncVersion) AS ct
        ON pe.PostID = ct.PostID
    JOIN 
        dbo.Posts p ON ct.PostID = p.PostID
    WHERE 
        ct.SYS_CHANGE_OPERATION = 'U'; -- Updated rows

    -- Log the synchronization version
    INSERT INTO dbo.PostEmbeddingsSyncLog (SyncVersion, SyncTime)
    VALUES (@CurrentVersion, GETDATE());
END;
GO

CREATE TABLE dbo.PostEmbeddingsSyncLog (
    SyncVersion BIGINT PRIMARY KEY,
    SyncTime DATETIME NOT NULL
);
GO

