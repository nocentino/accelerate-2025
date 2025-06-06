-- Demo 4 - Using external tables to store embeddings
-- SQL
-- Create a credential for external storage
USE StackOverflow_Embeddings;
GO

-- Create a master key with a secure password
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'YourStrongPassword123!';
GO

-- Create a database scoped credential for accessing external storage
CREATE DATABASE SCOPED CREDENTIAL ExternalStorageCredential
WITH 
    IDENTITY = 'S3 Access Key', -- Use 'S3 Access Key' for S3-compatible storage
    SECRET = 'PSFBSAZRHDBIJOIPAPKLOACBOAJCMKCDIJFPGBNNLI:A5AF16F59832ac290/a0ab+5F915B1F79b8db93IKAE'; -- Replace with your actual access and secret keys
GO


-- Create an external data source pointing to the storage location
CREATE EXTERNAL DATA SOURCE ExternalStorageSource
WITH (
    LOCATION = 's3://s200.fsa.lab/aen-sql-datavirt', -- Replace with your bucket or storage location
    CREDENTIAL = ExternalStorageCredential -- Use the credential created earlier
);
GO

-- Create a file format for Parquet files
CREATE EXTERNAL FILE FORMAT ParquetFileFormat
WITH (
    FORMAT_TYPE = PARQUET
);
GO



-- Enable advanced options
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
GO

-- Enable PolyBase export
EXEC sp_configure 'allow polybase export', 1;
RECONFIGURE;
GO

-- Populate the external table with embeddings from the PostEmbeddings table
CREATE EXTERNAL TABLE PostEmbeddingsExternal
WITH (
    LOCATION = '/', -- Path within the external storage
    DATA_SOURCE = ExternalStorageSource, -- Use the external data source created earlier
    FILE_FORMAT = ParquetFileFormat -- Use the file format created earlier
)
AS
SELECT TOP 10
    PostID,
    Embedding, -- Embedding vector from the PostEmbeddings table
    CreatedAt,
    UpdatedAt
FROM dbo.PostEmbeddings
--WHERE CreatedAt < DATEADD(YEAR, -1, GETDATE()); -- Filter for embeddings older than one year
GO


SELECT * FROM PostEmbeddingsExternal 

USE StackOverflow_Embeddings
GO
SELECT 
    YEAR(CreationDate) AS PostYear, -- Extract the year from the CreatedDate column
    COUNT(*) AS PostCount -- Count the number of posts for each year
FROM 
    dbo.Posts INNER JOIN PostEmbeddings pe ON Posts.Id = pe.PostID -- Join Posts and PostEmbeddings tables
GROUP BY 
    YEAR(CreationDate) -- Group by the year
ORDER BY 
    PostYear; -- Order the results by year

-- Create external tables for each year of posts, this take about 3 minutes to run
DECLARE @StartYear INT = 2008; -- Replace with the first year of posts
DECLARE @EndYear INT = YEAR(GETDATE()); -- Current year
DECLARE @Year INT = @StartYear;
DECLARE @SQL NVARCHAR(MAX);

WHILE @Year <= @EndYear
BEGIN
    -- Generate the CETAS statement for the current year
    SET @SQL = N'
    CREATE EXTERNAL TABLE PostEmbeddings_' + CAST(@Year AS NVARCHAR(4)) + N'
    WITH (
        LOCATION = ''/PostEmbeddings_Archive/' + CAST(@Year AS NVARCHAR(4)) + N'/'', -- Path for the year
        DATA_SOURCE = ExternalStorageSource, -- External data source
        FILE_FORMAT = ParquetFileFormat -- File format
    )
    AS
    SELECT 
        PostID,
        Embedding, -- Embedding vector from the PostEmbeddings table
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

-- Create a table to hold all records from 2022 and later
CREATE TABLE dbo.PostEmbeddings_2022_AndLater
(
    PostID INT PRIMARY KEY,
    Embedding VECTOR(768), 
    CreatedAt DATETIME2,
    UpdatedAt DATETIME2
);

-- Copy all records from the PostEmbeddings table for 2022 and later into the new table, this takes about 1.25 minutes to run
INSERT INTO dbo.PostEmbeddings_2022_AndLater (PostID, Embedding, CreatedAt, UpdatedAt)
SELECT PostID, Embedding, CreatedAt, UpdatedAt
FROM dbo.PostEmbeddings
WHERE CreatedAt >= '2022-01-01'; -- Adjust the date as needed

-- Drop the original PostEmbeddings table
DROP TABLE dbo.PostEmbeddings;
GO

-- Create a view to access the new table and all of the external tables
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


USE StackOverflow_Embeddings
GO
SELECT 
    YEAR(CreationDate) AS PostYear, -- Extract the year from the CreatedDate column
    COUNT(*) AS PostCount -- Count the number of posts for each year
FROM 
    dbo.Posts INNER JOIN PostEmbeddings pe ON Posts.Id = pe.PostID -- Join Posts and PostEmbeddings tables
GROUP BY 
    YEAR(CreationDate) -- Group by the year
ORDER BY 
    PostYear; -- Order the results by year

--clean up
DROP EXTERNAL TABLE PostEmbeddingsExternal;
DROP EXTERNAL DATA SOURCE ExternalStorageSource;
DROP EXTERNAL FILE FORMAT ParquetFileFormat;
DROP DATABASE SCOPED CREDENTIAL ExternalStorageCredential;
DROP MASTER KEY;

DECLARE @StartYear INT = 2008; -- Replace with the first year of posts
DECLARE @EndYear INT = YEAR(GETDATE()); -- Current year
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

