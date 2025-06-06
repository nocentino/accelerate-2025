-- Demo 2 - Snapshot offloaded embeddings - Snapshot closer to GPUs even between data centers (even in the cloud with CBS)

------------------------------------------------------------
-- Step 1 Create and test an External Model
------------------------------------------------------------
USE [StackOverflow]
GO

--Enable REST endpoint
sp_configure 'external rest endpoint enabled', 1;
RECONFIGURE WITH OVERRIDE;

DROP EXTERNAL MODEL ollama

CREATE EXTERNAL MODEL ollama
WITH (
    LOCATION = 'https://model-web.example.com:443/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO

--print the error log
EXEC sp_readerrorlog 0, 1

-- Test the model
PRINT 'Testing the external model by calling AI_GENERATE_EMBEDDINGS function...';
GO

BEGIN
    DECLARE @result NVARCHAR(MAX);
    SET @result = (SELECT CONVERT(NVARCHAR(MAX), AI_GENERATE_EMBEDDINGS(N'test text' USE MODEL ollama)));
    SELECT AI_GENERATE_EMBEDDINGS(N'test text' USE MODEL ollama) AS GeneratedEmbedding;

    IF @result IS NOT NULL
        PRINT 'Model test successful!';
    ELSE
        PRINT 'Model test failed. No result returned.';
END;
GO


------------------------------------------------------------
-- Step 3: Create a table to store the embeddings for the Posts table.
------------------------------------------------------------
USE [StackOverflow];
GO

-- Add a new filegroup for embeddings
ALTER DATABASE [StackOverflow]
ADD FILEGROUP EmbeddingsFileGroup;
GO

-- Add a file to the new filegroup
ALTER DATABASE [StackOverflow]
ADD FILE (
    NAME = N'StackOverflowEmbeddings',
    FILENAME = N'/var/opt/mssql/data/StackOverflowEmbeddings.ndf',
    SIZE = 100GB,       -- Initial size
    FILEGROWTH = 64MB   -- Growth increment
) TO FILEGROUP EmbeddingsFileGroup;
GO

-- Create the PostEmbeddings table in the EmbeddingsFileGroup
CREATE TABLE dbo.PostEmbeddings (
    PostID INT NOT NULL PRIMARY KEY,                -- Foreign key to Posts table
    Embedding  VECTOR(768) NOT NULL,                -- Vector embeddings (768 dimensions)
    CreatedAt DATETIME NOT NULL DEFAULT GETDATE(),  -- Timestamp for when the embedding was created
    UpdatedAt DATETIME NULL                         -- Timestamp for when the embedding was last updated
) ON EmbeddingsFileGroup;                           -- Specify the filegroup
GO

------------------------------------------------------------
-- Step 4: Generate embeddings for Posts table, build a chunk based off the title and the body
-- and store them in the PostEmbeddings table.
------------------------------------------------------------
USE [StackOverflow];
GO

DECLARE @BatchSize INT = 1000;     -- Number of rows to process in each batch
DECLARE @StartRow INT = 0;          -- Starting row for the current batch
DECLARE @MaxPostID INT;             -- Maximum PostID in the Posts table

-- Get the maximum PostID to determine the loop's end condition
SELECT @MaxPostID = MAX(Id) FROM dbo.Posts;

-- Loop through the Posts table in chunks of 10,000 rows
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
-- Step 5: Verify the embeddings have been generated and stored correctly
------------------------------------------------------------
USE [StackOverflow];
GO
-- Check the count of embeddings generated
SELECT TOP 10 p.Id, p.Title, pe.Embedding, pe.CreatedAt
FROM dbo.Posts p
JOIN dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE Embedding IS NOT NULL
ORDER BY pe.CreatedAt DESC;


------------------------------------------------------------
-- Step 6: Perform a similarity search using the embeddings
------------------------------------------------------------
DECLARE @QueryText NVARCHAR(MAX) = N'Find me posts about issuses with SQL Server performance';
DECLARE @QueryEmbedding VECTOR(768);
-- Generate embedding for the query text
SET @QueryEmbedding = AI_GENERATE_EMBEDDINGS(@QueryText USE MODEL ollama);

-- Perform similarity search
SELECT TOP 10 
    p.Id, 
    p.Title, 
    pe.Embedding, -- Correct column name for embeddings
    vector_distance('cosine', @QueryEmbedding, pe.Embedding) AS SimilarityScore -- Ensure correct column reference
FROM 
    dbo.Posts p
JOIN 
    dbo.PostEmbeddings pe ON p.Id = pe.PostID
WHERE 
    pe.Embedding IS NOT NULL -- Ensure the embeddings column is checked
ORDER BY 
    SimilarityScore ASC; -- Lower cosine distance means higher similarity