-- Demo 3 - Using change events to drive AI outcomes
-- Enable Change Tracking on the database
-- https://learn.microsoft.com/en-us/sql/relational-databases/track-changes/about-change-tracking-sql-server?view=sql-server-ver16

ALTER DATABASE StackOverflow_Embeddings
SET CHANGE_TRACKING = ON
(CHANGE_RETENTION = 2 DAYS, AUTO_CLEANUP = ON);
GO

USE StackOverflow_Embeddings;
GO

-- Enable Change Tracking on the Posts table
ALTER TABLE dbo.Posts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);
GO


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

-- Now let's update that row with new data
UPDATE dbo.Posts
SET 
    Body = '<p>I want to assign the decimal variable &quot;trans&quot; to the float variable &quot;this.Opacity&quot;.</p>',
    Title = 'Updated Post Title'
WHERE 
    Id = 4;
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

    -- Update embeddings for modified rows
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

CREATE TABLE dbo.PostEmbeddingsSyncLog (
    SyncVersion BIGINT PRIMARY KEY,
    SyncTime DATETIME NOT NULL
);
GO

EXEC dbo.UpdatePostEmbeddings;

SELECT * FROM dbo.PostEmbeddingsSyncLog

SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings
WHERE PostID = 4;