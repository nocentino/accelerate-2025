-- Demo 1: Semantic Search on SQL Server 2025
-- This demo showcases vector embeddings, semantic search, and row-level security features
SELECT @@VERSION AS SQLServerVersion;

------------------------------------------------------------
-- Step 1: Restore the AdventureWorks2025 database
-- https://github.com/nocentino/ollama-sql-faststart/
------------------------------------------------------------
ALTER DATABASE [AdventureWorks2025] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
GO

USE [master]; 
GO

RESTORE DATABASE [AdventureWorks2025]
FROM DISK = 'D:\SQLDATA1\AdventureWorks2025_FULL.bak'
WITH
    MOVE 'AdventureWorksLT2022_Data' TO 'D:\SQLDATA1\AdventureWorks2025_Data.mdf',
    MOVE 'AdventureWorksLT2022_Log' TO 'L:\SQLLOG\AdventureWorks2025_log.ldf',
    FILE = 1,
    NOUNLOAD,
    STATS = 5;
GO
------------------------------------------------------------
-- Step 2: Create and test an External Model
------------------------------------------------------------
USE [AdventureWorks2025]
GO

CREATE EXTERNAL MODEL Ollama
WITH (
    LOCATION = 'https://model-web:443/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO

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
-- Step 3: Add vector embeddings column to Product table
------------------------------------------------------------
ALTER TABLE [SalesLT].[Product]
ADD embeddings VECTOR(768), 
    chunk NVARCHAR(2000);
GO
------------------------------------------------------------
-- Step 4: Generate embeddings for product data. This will take about 10 seconds.
------------------------------------------------------------
UPDATE p
SET 
    chunk = p.Name + ' ' + ISNULL(p.Color, 'No Color') + ' ' + c.Name + ' ' + m.Name + ' ' + ISNULL(d.Description, ''),
    embeddings = AI_GENERATE_EMBEDDINGS(p.Name + ' ' + ISNULL(p.Color, 'No Color') + ' ' + c.Name + ' ' + m.Name + ' ' + ISNULL(d.Description, '') USE MODEL ollama)
FROM [SalesLT].[Product] p
JOIN [SalesLT].[ProductCategory] c ON p.ProductCategoryID = c.ProductCategoryID
JOIN [SalesLT].[ProductModel] m ON p.ProductModelID = m.ProductModelID
LEFT JOIN [SalesLT].[vProductAndDescription] d ON p.ProductID = d.ProductID AND d.Culture = 'en'
WHERE p.embeddings IS NULL;
GO

-- Review the created embeddings
SELECT TOP 10 
    ProductID, 
    Name, 
    chunk, 
    embeddings 
FROM [SalesLT].[Product];
GO

------------------------------------------------------------
-- Step 5: Perform basic vector search with different queries
------------------------------------------------------------
-- Example 1: Search for affordable red bikes
DECLARE @search_text NVARCHAR(MAX) = 'I am looking for a red bike and I dont want to spend a lot';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

SELECT TOP(4)
    p.ProductID,
    p.Name,
    p.chunk,
    vector_distance('cosine', @search_vector, p.embeddings) AS distance
FROM [SalesLT].[Product] p
ORDER BY distance;
GO

-- Example 2: Search for lightweight helmets
DECLARE @search_text NVARCHAR(MAX) = 'I am looking for a safe helmet that does not weigh much';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

SELECT TOP(4)
    p.ProductID,
    p.Name,
    p.chunk,
    vector_distance('cosine', @search_vector, p.embeddings) AS distance
FROM [SalesLT].[Product] p
ORDER BY distance;
GO

------------------------------------------------------------
-- Step 6: Create a Vector Index for faster searching
------------------------------------------------------------
-- Enable trace flags for vector features
DBCC TRACEON (466, 474, 13981, -1);
GO

-- Verify trace flags are enabled
DBCC TRACESTATUS;
GO

-- Create vector index using approximate nearest neighbors (ANN)
CREATE VECTOR INDEX vec_idx ON [SalesLT].[Product]([embeddings])
WITH (
    metric = 'cosine',
    type = 'diskann',
    maxdop = 8
);
GO

-- Use vector_search function with price filter
DECLARE @search_text NVARCHAR(MAX) = 'Do you sell any padded seats that are good on trails?';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

SELECT
    t.ProductID,
    t.Name,
    t.chunk,
    s.distance,
    t.ListPrice
FROM vector_search(
    table = [SalesLT].[Product] AS t,
    column = [embeddings],
    similar_to = @search_vector,
    metric = 'cosine',
    top_n = 10
) AS s
WHERE ListPrice < 40
ORDER BY s.distance;
GO

------------------------------------------------------------
-- Step 7: Implement Row-Level Security
------------------------------------------------------------
-- Add a column for sales person without domain prefix
ALTER TABLE SalesLT.Customer
ADD SalesPersonShort NVARCHAR(256) NULL;
GO

-- Update the column with the short salespeople names
UPDATE SalesLT.Customer
SET SalesPersonShort = REPLACE(SalesPerson, 'adventure-works\', '')
WHERE SalesPerson IS NOT NULL;
GO

-- View the distinct salespeople
SELECT 
    SalesPersonShort AS SalesPerson, 
    COUNT(*) AS CustomerCount
FROM [SalesLT].[Customer] 
GROUP BY SalesPersonShort 
ORDER BY CustomerCount DESC;
GO

-- Create test user
CREATE USER [shu0] WITHOUT LOGIN;
GO

-- Create predicate function for filtering
CREATE FUNCTION SalesLT.fn_SalesPersonFilter(@SalesPerson NVARCHAR(256))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS AccessResult
    WHERE @SalesPerson = USER_NAME()  -- Filter by current username
    OR USER_NAME() = 'dbo'            -- Allow dbo to see all rows
);
GO

-- Create security policy
CREATE SECURITY POLICY SalesLT.SalesOrderHeaderSecurityPolicy
ADD FILTER PREDICATE SalesLT.fn_SalesPersonFilter(SalesPersonShort)
ON SalesLT.Customer
WITH (STATE = ON);
GO

-- Test RLS as admin user - should show all data
SELECT 
    c.SalesPersonShort,
    COUNT(soh.SalesOrderID) AS TotalOrders,
    SUM(soh.TotalDue) AS TotalSales
FROM 
    SalesLT.SalesOrderHeader AS soh 
    INNER JOIN SalesLT.Customer AS c ON soh.CustomerID = c.CustomerID
GROUP BY 
    c.SalesPersonShort
ORDER BY 
    TotalSales DESC;
GO

------------------------------------------------------------
-- Step 8: Grant permissions and test as regular user
------------------------------------------------------------
GRANT SELECT ON SalesLT.Customer TO [shu0];
GRANT SELECT ON SalesLT.SalesOrderHeader TO [shu0];
GRANT SELECT ON SalesLT.SalesOrderDetail TO [shu0];
GRANT SELECT ON SalesLT.Product TO [shu0];
GRANT EXECUTE ON EXTERNAL MODEL::Ollama TO [shu0]; -- Allow user to generate embeddings against our model
GO

-- Test as shu0 user - should only see data for shu0
EXECUTE AS USER = 'shu0';

-- Test vector search with RLS applied
DECLARE @search_text NVARCHAR(MAX) = 'Im looking for seat sales';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

-- Aggregated results
SELECT 
    c.SalesPersonShort,
    COUNT(p.ProductID) AS TotalProducts,
    SUM(sod.LineTotal) AS TotalSales
FROM 
    [SalesLT].[Product] p
    INNER JOIN SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
    INNER JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
    INNER JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE 
    vector_distance('cosine', @search_vector, p.embeddings) < 0.5
GROUP BY 
    c.SalesPersonShort
ORDER BY 
    TotalSales DESC;

-- Detailed results
SELECT 
    c.SalesPersonShort,
    p.ProductID,
    p.Name AS ProductName,
    sod.SalesOrderID,
    sod.OrderQty,
    sod.LineTotal
FROM 
    [SalesLT].[Product] p
    INNER JOIN SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
    INNER JOIN SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
    INNER JOIN SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE 
    vector_distance('cosine', @search_vector, p.embeddings) < 0.5
ORDER BY 
    c.SalesPersonShort, sod.SalesOrderID;

-- Return to admin context
REVERT;
GO