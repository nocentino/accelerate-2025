-- Demo 4 - Using external tables to store embeddings
-- SQL
-- Create a credential for external storage
USE StackOverflow;
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
    LOCATION = 's3://s200.fsa.lab/aen-sql-backups', -- Replace with your bucket or storage location
    CREDENTIAL = ExternalStorageCredential -- Use the credential created earlier
);
GO

-- Create a file format for Parquet files
CREATE EXTERNAL FILE FORMAT ParquetFileFormat
WITH (
    FORMAT_TYPE = PARQUET
);
GO



-- Create an external table for storing embeddings
CREATE EXTERNAL TABLE PostEmbeddingsExternal (
    PostID INT NOT NULL,
    Embedding VECTOR(768), -- Replace 768 with the dimensionality of your embeddings
    CreatedDate DATETIME,
    LastUpdatedDate DATETIME
)
WITH (
    LOCATION = '/posts_embeddings/', -- Path within the external storage
    DATA_SOURCE = ExternalStorageSource, -- Use the external data source created earlier
    FILE_FORMAT = ParquetFileFormat -- Use the file format created earlier
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
    LOCATION = '/posts_embeddings/', -- Path within the external storage
    DATA_SOURCE = ExternalStorageSource, -- Use the external data source created earlier
    FILE_FORMAT = ParquetFileFormat -- Use the file format created earlier
)
AS
SELECT TOP 10
    PostID,
    Embedding, -- Embedding vector from the PostEmbeddings table
    CreatedAt AS CreatedDate, -- Map CreatedAt to CreatedDate
    UpdatedAt AS LastUpdatedDate -- Map UpdatedAt to LastUpdatedDate
FROM dbo.PostEmbeddings
--WHERE CreatedAt < DATEADD(YEAR, -1, GETDATE()); -- Filter for embeddings older than one year
GO

-- Query the external table
SELECT TOP 10 *
FROM PostEmbeddingsExternal;
GO


USE StackOverflow
GO
SELECT 
    YEAR(CreationDate) AS PostYear, -- Extract the year from the CreatedDate column
    COUNT(*) AS PostCount -- Count the number of posts for each year
FROM 
    dbo.Posts
GROUP BY 
    YEAR(CreationDate) -- Group by the year
ORDER BY 
    PostYear; -- Order the results by year