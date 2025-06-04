-- Demo 1 - Semantic Search on SQL Server 2025


-- Step 1: Restore the AdventureWorks2025 database from a backup file -------------------
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
----------------------------------------------------------------------------------------

-- Step 2: Create and test an External Model----
USE [AdventureWorks2025]
GO

CREATE EXTERNAL MODEL ollama
WITH (
    LOCATION = 'https://model-web:443/api/embed',
    API_FORMAT = 'Ollama',
    MODEL_TYPE = EMBEDDINGS,
    MODEL = 'nomic-embed-text'
);
GO

PRINT 'Testing the external model by calling AI_GENERATE_EMBEDDINGS function...';
GO
BEGIN
    DECLARE @result NVARCHAR(MAX);
    SET @result = (SELECT CONVERT(NVARCHAR(MAX), AI_GENERATE_EMBEDDINGS(N'test text' USE MODEL ollama)))
    SELECT AI_GENERATE_EMBEDDINGS(N'test text' USE MODEL ollama) AS GeneratedEmbedding

    IF @result IS NOT NULL
        PRINT 'Model test successful. Result: ' + @result;
    ELSE
        PRINT 'Model test failed. No result returned.';
END;
GO
----------------------------------------------------------------------------------------


-- Step 3: Altering a Table to Add Vector Embeddings Column ----------------------------
USE [AdventureWorks2025];
GO

ALTER TABLE [SalesLT].[Product]
ADD embeddings VECTOR(768), 
    chunk NVARCHAR(2000);
GO
----------------------------------------------------------------------------------------


-- Step 4: CREATE THE EMBEDDINGS (This demo is based off the MS SQL 2025 demo repository)
UPDATE p
SET 
 [chunk] = p.Name + ' ' + ISNULL(p.Color, 'No Color') + ' ' + c.Name + ' ' + m.Name + ' ' + ISNULL(d.Description, ''),
 [embeddings] = AI_GENERATE_EMBEDDINGS(p.Name + ' ' + ISNULL(p.Color, 'No Color') + ' ' + c.Name + ' ' + m.Name + ' ' + ISNULL(d.Description, '') USE MODEL ollama)
FROM [SalesLT].[Product] p
JOIN [SalesLT].[ProductCategory] c ON p.ProductCategoryID = c.ProductCategoryID
JOIN [SalesLT].[ProductModel] m ON p.ProductModelID = m.ProductModelID
LEFT JOIN [SalesLT].[vProductAndDescription] d ON p.ProductID = d.ProductID AND d.Culture = 'en'
WHERE p.embeddings IS NULL;

-- Review the created embeddings
SELECT TOP 10 chunk, embeddings, * 
FROM [SalesLT].[Product] p
----------------------------------------------------------------------------------------


-- Step 5: Perform Vector Search -------------------------------------------------------
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
----------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------


-- Step 6: Create a Vector Index - Uses Approximate Nearest Neighbors or ANN------------
-- Enable trace flags for vector features
DBCC TRACEON (466, 474, 13981, -1);
GO

-- Check trace flags status
DBCC TRACESTATUS;
GO


-- Create a vector index
CREATE VECTOR INDEX vec_idx ON [SalesLT].[Product]([embeddings])
WITH (
    metric = 'cosine',
    type = 'diskann',
    maxdop = 8
);
GO


-- ANN Search and then applies the predicate specified in the WHERE clause.
DECLARE @search_text NVARCHAR(MAX) = 'Do you sell any padded seats that are good on trails?';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

SELECT
    t.ProductID,
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
----------------------------------------------------------------------------------------


-- Using row level security to protect data
USE [AdventureWorks2025];
GO

-- add a column for sales person that removes the domain
ALTER TABLE SalesLT.Customer
ADD SalesPersonShort NVARCHAR(256) NULL;
GO

UPDATE SalesLT.Customer
SET SalesPersonShort = REPLACE(SalesPerson, 'adventure-works\', '')
WHERE SalesPerson IS NOT NULL;

select distinct([SalesPersonShort]) as SalesPerson , count(*)
FROM [AdventureWorks2025].[SalesLT].[Customer] group by [SalesPersonShort] order by count(*) desc;
GO

CREATE USER [shu0] WITHOUT LOGIN;
GO


CREATE FUNCTION SalesLT.fn_SalesPersonFilter(@SalesPerson NVARCHAR(256))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN (
    SELECT 1 AS AccessResult
    WHERE @SalesPerson = USER_NAME()  -- Replace USER_NAME() with your logic for identifying the user
     OR USER_NAME() = 'dbo'           -- Allow the 'sa' user to see all rows
);
GO


CREATE SECURITY POLICY SalesLT.SalesOrderHeaderSecurityPolicy
ADD FILTER PREDICATE SalesLT.fn_SalesPersonFilter(SalesPersonShort)
ON SalesLT.Customer
WITH (STATE = ON);
GO

-- Test the row-level security by aggregating total sales by SalesPerson
SELECT 
    c.SalesPersonShort,
    COUNT(soh.SalesOrderID) AS TotalOrders,
    SUM(soh.TotalDue) AS TotalSales
FROM 
    SalesLT.SalesOrderHeader AS soh INNER JOIN SalesLT.Customer AS c ON soh.CustomerID = c.CustomerID
GROUP BY 
    c.SalesPersonShort
ORDER BY 
    TotalSales DESC;
---


GRANT SELECT ON SalesLT.Customer TO [shu0];
GRANT SELECT ON SalesLT.SalesOrderHeader TO [shu0];
GRANT SELECT ON SalesLT.SalesOrderDetail TO [shu0];
GRANT SELECT ON SalesLT.Product TO [shu0];
--GRANT EXECUTE ON EXTERNAL MODEL::Ollama TO [shu0]; --case sensitive
GRANT EXECUTE ON EXTERNAL MODEL::ollama TO [shu0];


-- Test the row-level security by aggregating total sales by SalesPerson
EXECUTE AS USER = 'shu0';

DECLARE @search_text NVARCHAR(MAX) = 'Im looking for yellow seat sales';
DECLARE @search_vector VECTOR(768) = AI_GENERATE_EMBEDDINGS(@search_text USE MODEL ollama);

SELECT 
    c.SalesPersonShort,
    COUNT(p.ProductID) AS TotalProducts,
    SUM(sod.LineTotal) AS TotalSales
FROM 
    [SalesLT].[Product] p
INNER JOIN 
    SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
INNER JOIN 
    SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
INNER JOIN 
    SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE 
    vector_distance('cosine', @search_vector, p.embeddings) < 0.5 -- Adjust threshold as needed
GROUP BY 
    c.SalesPersonShort
ORDER BY 
    TotalSales DESC;

SELECT 
    c.SalesPersonShort,
    p.ProductID,
    p.Name AS ProductName,
    sod.SalesOrderID,
    sod.OrderQty,
    sod.LineTotal
FROM 
    [SalesLT].[Product] p
INNER JOIN 
    SalesLT.SalesOrderDetail sod ON p.ProductID = sod.ProductID
INNER JOIN 
    SalesLT.SalesOrderHeader soh ON sod.SalesOrderID = soh.SalesOrderID
INNER JOIN 
    SalesLT.Customer c ON soh.CustomerID = c.CustomerID
WHERE 
    vector_distance('cosine', @search_vector, p.embeddings) < 0.5
ORDER BY 
    c.SalesPersonShort, sod.SalesOrderID;
REVERT;
