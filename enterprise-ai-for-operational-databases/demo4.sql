-- Demo 4 - Using external tables to store embeddings
-- This demo showcases SQL Server's external table capabilities with Pure Storage FlashBlade
-- to efficiently tier and manage large-scale AI vector embeddings
------------------------------------------------------------
-- Step 1: Set up authentication for external storage
------------------------------------------------------------
USE StackOverflow_Embeddings;
GO

/*
    Create a master key with a secure password.
*/
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPassword123!';
GO

/*
    Create a database scoped credential for accessing external object storage.
*/
CREATE DATABASE SCOPED CREDENTIAL ExternalStorageCredential
WITH 
    IDENTITY = 'S3 Access Key', -- Use 'S3 Access Key' for S3-compatible storage
    SECRET = 'PSFBSAZRHDBIJOIPAPKLOACBOAJCMKCDIJFPGBNNLI:A5AF16F59832ac290/a0ab+5F915B1F79b8db93IKAE';
GO

------------------------------------------------------------
-- Step 2: Configure external data source and file format
------------------------------------------------------------
/*
    Create an external data source pointing to the Pure Storage FlashBlade location.
    FlashBlade's high-throughput object storage provides ideal performance characteristics
    for large-scale vector embedding storage and retrieval.
*/
CREATE EXTERNAL DATA SOURCE ExternalStorageSource
WITH (
    LOCATION = 's3://s200.fsa.lab/aen-sql-datavirt', -- Pure FlashBlade S3 endpoint
    CREDENTIAL = ExternalStorageCredential
);
GO

/*
    Create a file format for Parquet files.
    Pure Storage FlashBlade efficiently handles columnar formats like Parquet,
    enabling high-performance analytics on vector embeddings.
*/
CREATE EXTERNAL FILE FORMAT ParquetFileFormat
WITH (
    FORMAT_TYPE = PARQUET
);
GO

------------------------------------------------------------
-- Step 3: Enable and configure PolyBase for external data access
------------------------------------------------------------
/*
    Enable advanced options for PolyBase configuration.
*/
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

/*
    Enable PolyBase export for external table creation.
    Pure Storage FlashBlade's high throughput ensures CETAS operations
    (Create External Table As Select) complete rapidly even with large datasets.
*/
EXEC sp_configure 'allow polybase export', 1;
RECONFIGURE;
GO

------------------------------------------------------------
-- Step 4: Create sample external table for testing
------------------------------------------------------------
/*
    Create an initial external table to validate the configuration.
    Pure Storage FlashBlade provides consistent, high-performance access
    to external tables, eliminating the typical performance penalty of
    accessing data outside the database.
*/
CREATE EXTERNAL TABLE PostEmbeddingsExternal
WITH (
    LOCATION = '/', -- Path within the external storage
    DATA_SOURCE = ExternalStorageSource,
    FILE_FORMAT = ParquetFileFormat
)
AS
SELECT TOP 10
    PostID,
    Embedding, -- Embedding vector from the PostEmbeddings table
    CreatedAt,
    UpdatedAt
FROM dbo.PostEmbeddings;
GO

-- Verify the external table can be queried
SELECT * FROM PostEmbeddingsExternal;

------------------------------------------------------------
-- Step 5: Analyze data distribution by year
------------------------------------------------------------
/*
    Analyze post distribution by year to plan our data tiering strategy.
    Pure Storage's architecture enables intelligent data placement based on
    access patterns and business requirements.
*/
USE StackOverflow_Embeddings;
GO

SELECT 
    YEAR(CreationDate) AS PostYear, -- Extract the year from the CreatedDate column
    COUNT(*) AS PostCount -- Count the number of posts for each year
FROM 
    dbo.Posts INNER JOIN PostEmbeddings pe ON Posts.Id = pe.PostID
GROUP BY 
    YEAR(CreationDate)
ORDER BY 
    PostYear;

------------------------------------------------------------
-- Step 6: Implement year-based tiering to external storage
------------------------------------------------------------
/*
    Create external tables for each year of posts.
    Pure Storage FlashBlade's object storage provides an ideal environment for cold data,
    with high throughput, excellent data reduction, and dramatically lower cost
    compared to primary storage.
*/
DECLARE @StartYear INT = 2008;
DECLARE @EndYear INT = YEAR(GETDATE());
DECLARE @Year INT = @StartYear;
DECLARE @SQL NVARCHAR(MAX);

WHILE @Year <= @EndYear
BEGIN
    -- Generate the CETAS statement for the current year
    SET @SQL = N'
    CREATE EXTERNAL TABLE PostEmbeddings_' + CAST(@Year AS NVARCHAR(4)) + N'
    WITH (
        LOCATION = ''/PostEmbeddings_Archive/' + CAST(@Year AS NVARCHAR(4)) + N'/'',
        DATA_SOURCE = ExternalStorageSource,
        FILE_FORMAT = ParquetFileFormat
    )
    AS
    SELECT 
        PostID,
        Embedding,
        CreatedAt,
        UpdatedAt
    FROM dbo.PostEmbeddings INNER JOIN dbo.Posts ON PostEmbeddings.PostID = Posts.Id
    WHERE YEAR(CreationDate) = ' + CAST(@Year AS NVARCHAR(4)) + N';
    ';

    -- Execute the CETAS statement
    EXEC sp_executesql @SQL;

    -- Move to the next year
    SET @Year = @Year + 1;
    PRINT 'Created external table for year ' + CAST(@Year - 1 AS NVARCHAR(4));
END;
GO

------------------------------------------------------------
-- Step 7: Create optimized storage for recent data
------------------------------------------------------------
/*
    Create a table to hold recent data (2022 and later) for optimal performance.
    Pure Storage's high-performance flash storage enables fast access to recent,
    frequently-accessed data while older data remains accessible on FlashBlade.
*/
CREATE TABLE dbo.PostEmbeddings_2022_AndLater
(
    PostID INT PRIMARY KEY CLUSTERED,
    Embedding VECTOR(768), 
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
) ON EmbeddingsFileGroup; -- Specify the filegroup;

/*
    Copy recent records from the original table.
    Pure Storage's high throughput ensures this data migration
    completes quickly, minimizing application downtime.
*/
INSERT INTO dbo.PostEmbeddings_2022_AndLater (PostID, Embedding, CreatedAt, UpdatedAt)
SELECT PostID, Embedding, CreatedAt, UpdatedAt
FROM dbo.PostEmbeddings pe INNER JOIN dbo.Posts p ON pe.PostID = p.Id
WHERE p.CreationDate >= '2022-01-01';

-- After migration, drop the original table that contained all data
DROP TABLE dbo.PostEmbeddings;
GO

------------------------------------------------------------
-- Step 8: Create a unified view across all data sources
------------------------------------------------------------
/*
    Create a view to provide transparent access across all data sources.
    Pure Storage's consistent performance across FlashArray and FlashBlade
    ensures seamless query execution regardless of data location.
*/
CREATE VIEW dbo.PostEmbeddings
AS
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2022_AndLater
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2021 
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2020
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2019
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2018
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2017
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2016
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2015
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2014
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2013
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2012
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2011
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2010
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2009
UNION ALL
SELECT PostID, Embedding, CreatedAt, UpdatedAt FROM dbo.PostEmbeddings_2008
GO

------------------------------------------------------------
-- Step 9: Verify data accessibility post-migration
------------------------------------------------------------
/*
    Verify all data remains accessible through the view.
    Pure Storage's hybrid architecture ensures high performance for both
    hot data on FlashArray and warm/cold data on FlashBlade.
    Notice the MAXDOP option to optimize parallel processing driving IO from FlashBlade in Parallel
    and also reading from FlashArray for the most recent data.
*/
USE StackOverflow_Embeddings
GO
SELECT 
    YEAR(CreationDate) AS PostYear,
    COUNT(*) AS PostCount
FROM 
    dbo.Posts INNER JOIN PostEmbeddings pe ON Posts.Id = pe.PostID
GROUP BY 
    YEAR(CreationDate)
ORDER BY 
    PostYear
OPTION (MAXDOP 16);

------------------------------------------------------------
-- Step 10: Analyze storage efficiency
------------------------------------------------------------
/*
    Check the size of the hot data table.
    Pure Storage's data reduction technologies typically achieve 2.5:1 or better
    data reduction for vector embeddings, significantly reducing storage costs.
*/



-- Check the size of the new table, which should be significantly smaller than the original PostEmbeddings table
EXEC sp_spaceused N'dbo.PostEmbeddings_2022_AndLater';
GO

-- Shrink the file to reclaim space after the migration
DBCC SHRINKFILE (N'StackOverflowEmbeddings' , 2695)
GO

-- Go check the space on the FlashArray and the FlashBlade

/*
    The total storage footprint for embeddings is optimized by:
    1. Pure FlashArray's data reduction for hot data (recent embeddings)
    2. Pure FlashBlade's efficient object storage for cold data (archived embeddings)
    3. The transparent data virtualization provided by SQL Server's external tables
*/
------------------------------------------------------------
-- Step 11: Optimize vector search with vector indexing
------------------------------------------------------------
/*
    Enable trace flags required for vector features.
    Pure Storage's optimized storage platform provides the performance
    required for advanced vector operations and indexing.
*/
DBCC TRACEON (466, 474, 13981, -1);
GO

-- Verify trace flags are enabled
DBCC TRACESTATUS;
GO

/*
    Create a vector index for faster similarity searches on recent data.
    Pure Storage's high IOPS capabilities enable efficient creation and
    maintenance of compute-intensive vector indexes.
*/
CREATE VECTOR INDEX vec_idx ON dbo.PostEmbeddings_2022_AndLater([Embedding])
WITH (
    metric = 'cosine',
    type = 'diskann',
    maxdop = 8
);
GO

------------------------------------------------------------
-- Step 12: Test semantic search performance
-- CHANGE CONNECTION TO AEN-SQL-25-B BEFORE RUNNING THIS
------------------------------------------------------------
/*
    Perform a similarity search across all data.
    Pure Storage's architecture ensures consistent performance for complex
    vector operations even when data spans multiple storage tiers.
*/
DECLARE @QueryText NVARCHAR(MAX) = N'Find me posts about issuses with SQL Server performance'; --<---this is intentionally misspelled to highlight the similarity search
DECLARE @QueryEmbedding VECTOR(768);
-- Generate embedding for the query text
SET @QueryEmbedding = AI_GENERATE_EMBEDDINGS(@QueryText USE MODEL ollama);

-- Perform similarity search
SELECT TOP 10 
    p.Id, 
    p.Title, 
    pe.Embedding,
    vector_distance('cosine', @QueryEmbedding, pe.Embedding) AS SimilarityScore
FROM 
    dbo.Posts p
JOIN 
    dbo.PostEmbeddings pe ON p.Id = pe.PostID 
WHERE 
    pe.Embedding IS NOT NULL 
ORDER BY 
    SimilarityScore ASC;



------------------------------------------------------------
-- Step 13: Clean up resources (for demo purposes)
------------------------------------------------------------
-- Drop external table resources
DROP EXTERNAL TABLE PostEmbeddingsExternal;
DROP EXTERNAL DATA SOURCE ExternalStorageSource;
DROP EXTERNAL FILE FORMAT ParquetFileFormat;
DROP DATABASE SCOPED CREDENTIAL ExternalStorageCredential;
DROP MASTER KEY;

-- Drop all year-based external tables
DECLARE @StartYear INT = 2008;
DECLARE @EndYear INT = YEAR(GETDATE());
DECLARE @Year INT = @StartYear;
DECLARE @SQL NVARCHAR(MAX);

WHILE @Year <= @EndYear
BEGIN
    -- Generate the DROP EXTERNAL TABLE statement for the current year
    SET @SQL = N'DROP EXTERNAL TABLE PostEmbeddings_' + CAST(@Year AS NVARCHAR(4)) + N';';

    -- Execute the DROP statement
    EXEC sp_executesql @SQL;

    -- Move to the next year
    SET @Year = @Year + 1;
    PRINT 'Dropped external table for year ' + CAST(@Year - 1 AS NVARCHAR(4));
END;
GO

