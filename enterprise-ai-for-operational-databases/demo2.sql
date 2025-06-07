-- Demo 2 - Exploring Embeddings and Storage in SQL Server
-- This demo showcases SQL Server's vector database capabilities and Pure Storage's
-- efficient handling of AI embeddings with optimal data reduction and performance
------------------------------------------------------------
-- Step 1: Create a table to store the embeddings for the Posts table
------------------------------------------------------------
USE [StackOverflow_Embeddings];
GO

/*
    Add a new filegroup for embeddings.
    Using a dedicated filegroup for vector embeddings enables us to isolate the performance metrics more easily to observe
    the impact of Pure Storage's data reduction and performance capabilities.
*/
ALTER DATABASE [StackOverflow]
ADD FILEGROUP EmbeddingsFileGroup;
GO

/*
    Add a file to the new filegroup with ample size for embeddings.
    Pure Storage's always-thin provisioning means you only consume what you actually use,
    while maintaining consistent high performance regardless of capacity utilization.
*/
ALTER DATABASE [StackOverflow]
ADD FILE (
    NAME = N'StackOverflowEmbeddings',
    FILENAME = N'E:\SQLEMBEDDINGS\StackOverflow_Embeddings.ndf',
    SIZE = 100GB,       -- Initial size
    FILEGROWTH = 64MB   -- Growth increment
) TO FILEGROUP EmbeddingsFileGroup;
GO

/*
    Create the PostEmbeddings table in the dedicated EmbeddingsFileGroup.
    Pure Storage's industry-leading data reduction technology provides
    significant space savings for embeddings data, which typically contains
    similar patterns that compress inefficiently.
*/
CREATE TABLE dbo.PostEmbeddings (
    PostID INT NOT NULL PRIMARY KEY CLUSTERED,      -- Foreign key to Posts table
    Embedding VECTOR(768) NOT NULL,                 -- Vector embeddings (768 dimensions)
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),  -- Timestamp for when the embedding was created
    UpdatedAt DATETIME NULL                         -- Timestamp for when the embedding was last updated
) ON EmbeddingsFileGroup;                           -- Specify the filegroup
GO

------------------------------------------------------------
-- Step 2: Generate embeddings for Posts table using AI_GENERATE_EMBEDDINGS
------------------------------------------------------------
USE [StackOverflow_Embeddings];
GO

/*
    This batch process generates embeddings for all posts.
    Pure Storage's consistently low latency and high throughput ensure
    optimal performance during intensive AI operations like embedding generation,
    even when processing millions of records.
*/
DECLARE @BatchSize INT = 1000;     -- Number of rows to process in each batch
DECLARE @StartRow INT = 0;         -- Starting row for the current batch
DECLARE @MaxPostID INT;            -- Maximum PostID in the Posts table

-- Get the maximum PostID to determine the loop's end condition
SELECT @MaxPostID = MAX(Id) FROM dbo.Posts;

-- Loop through the Posts table in chunks to manage memory usage
WHILE @StartRow <= @MaxPostID
BEGIN
    -- Insert embeddings for the current batch
    INSERT INTO dbo.PostEmbeddings (PostID, Embedding, CreatedAt)
    SELECT 
        p.Id AS PostID,
        AI_GENERATE_EMBEDDINGS(p.Title USE MODEL ollama) AS Embedding, -- Generate embeddings
        GETDATE() AS CreatedAt -- Timestamp for when the embedding is created
    FROM 
        dbo.Posts p
    WHERE 
        p.Id BETWEEN @StartRow AND @StartRow + @BatchSize - 1 -- Process rows in the current batch
        AND NOT EXISTS (
            SELECT 1 
            FROM dbo.PostEmbeddings pe 
            WHERE pe.PostID = p.Id
        ) -- Avoid duplicate entries
        AND p.Title IS NOT NULL; -- Skip rows where Title is NULL

    -- Increment the starting row for the next batch
    SET @StartRow = @StartRow + @BatchSize;
    PRINT 'Processed rows from ' + CAST(@StartRow - @BatchSize AS NVARCHAR(10)) + ' to ' + CAST(@StartRow - 1 AS NVARCHAR(10));
END;
GO

------------------------------------------------------------
-- Step 3: Verify the embeddings have been generated and stored correctly
------------------------------------------------------------
USE [StackOverflow_Embeddings];
GO

/*
    Verify that embeddings were successfully generated and stored.
    Pure Storage's consistency and reliability ensure data integrity
    while handling the complex vector data types used for AI operations.
    Each embedding is a 768-dimensional vector, which captures the semantic meaning of the post title.
    Which are n-dimensional floats, meaning they can be large in size and challenging to data reduce. But not with Pure Storage!
*/
SELECT TOP 10 p.Id, p.Title, pe.Embedding, pe.CreatedAt
FROM dbo.Posts p
JOIN dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE Embedding IS NOT NULL;

------------------------------------------------------------
-- Step 4: Perform a similarity search using the embeddings
------------------------------------------------------------
/*
    This query demonstrates semantic similarity search using vector embeddings.
    Pure Storage's high IOPS and low latency enable near-instantaneous responses
    even when calculating vector distances across large embedding datasets.
*/
DECLARE @QueryText NVARCHAR(MAX) = N'Find me posts about issuses with SQL Server performance'; --<---this is intentionally misspelled to highlight the similarity search
DECLARE @QueryEmbedding VECTOR(768);
-- Generate embedding for the query text
SET @QueryEmbedding = AI_GENERATE_EMBEDDINGS(@QueryText USE MODEL ollama);

-- Perform similarity search
SELECT TOP 10 
    p.Id, 
    p.Title, 
    pe.Embedding, -- Embedding vector
    vector_distance('cosine', @QueryEmbedding, pe.Embedding) AS SimilarityScore -- Calculate vector distance
FROM 
    dbo.Posts p
JOIN 
    dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE 
    pe.Embedding IS NOT NULL -- Ensure the embeddings column is checked
ORDER BY 
    SimilarityScore ASC; -- Lower cosine distance means higher similarity

------------------------------------------------------------
-- Step 5: Query the size of the PostEmbeddings table and examine data reduction
------------------------------------------------------------
/*
    Pure Storage provides exceptional data reduction for embeddings through 
    its industry-leading compression algorithms and deduplication technology.
*/
-- Query to get the size of the PostEmbeddings table
EXEC sp_spaceused N'dbo.PostEmbeddings';

-- An embedding is a vector representation of a piece of text, such as a post title or body. 
-- It captures the semantic meaning of the text in a high-dimensional space, allowing for similarity searches and comparisons.
-- Since they're n-dimensional floats, the size of the embeddings table is determined by the number of posts and the size of each embedding vector. 
-- In this case, each embedding is a 768-dimensional vector, which means it requires significant storage space.
SELECT TOP 1 * from dbo.PostEmbeddings;

-- Let's examine the data reduction for this data set. Pure Storage typically achieves around 3.5:1 reduction for vector embeddings
-- This reduction happens automatically and transparently, with zero performance impact
-- The web UI at the URL below provides a detailed view of the storage efficiency
open https://sn1-x90r2-f06-33.puretec.purestorage.com/storage/volumes/volume/vvol-aen-sql-25-a-1e763fbf-vg/Data-367b471f