-- Demo 4: Backup Performance with ZSTD Compression
-- This demo showcases SQL Server 2025's new ZSTD compression capabilities combined with Pure Storage's 
-- high-throughput storage for unprecedented backup and restore performance on FlashBlade
------------------------------------------------------------
-- Step 1: Verify SQL Server Version
------------------------------------------------------------
SELECT @@VERSION AS SQLServerVersion 

------------------------------------------------------------
-- Step 2: Baseline backup performance tests using NUL device
------------------------------------------------------------
/*
    First test backup speed with no compression. 
    These tests establish a CPU-unconstrained baseline by writing to the NUL device.
    Pure Storage's high-performance arrays eliminate storage as a bottleneck,
    allowing CPU and memory to be fully utilized during database operations.
*/
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH NO_COMPRESSION, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'No compression to NUL'
GO

/*
    Test with legacy MS_XPRESS compression algorithm.
    The MS_XPRESS algorithm has been SQL Server's default compression method,
    providing decent compression with moderate CPU usage.
*/
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION (ALGORITHM = MS_XPRESS), 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'Compression using MS_XPRESS (default) to NUL'
GO

/*
    Test with new ZSTD compression at default level.
    SQL Server 2025's ZSTD compression delivers better compression ratios with better performance,
    reducing both backup time and storage requirements.
*/
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION (ALGORITHM = ZSTD), 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'Compression using ZSTD (default level) to NUL'
GO

------------------------------------------------------------
-- Step 3: Testing backup performance to Pure Storage FlashBlade via S3
------------------------------------------------------------
/*
    Backup with no compression to S3 on Pure Storage FlashBlade.
    Pure Storage FlashBlade provides industry-leading performance for backup targets,
    enabling backup throughput exceeding 1TB/minute when used with SQL Server's
    parallel backup streams.
*/
BACKUP DATABASE [TPCC] 
TO   URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_4.bak'
WITH NO_COMPRESSION, 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'No compression to S3'
GO

/*
    Backup with MS_XPRESS compression to S3 on Pure Storage FlashBlade.
    Pure Storage's consistent performance allows for stable, predictable backup windows
    even with growing data volumes.
*/
BACKUP DATABASE [TPCC] 
TO   URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_4.bak'
WITH COMPRESSION, 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'Compression using MS_XPRESS to S3'
GO

------------------------------------------------------------
-- Step 4: Testing ZSTD compression levels with Pure Storage FlashBlade
------------------------------------------------------------
/*
    Backup with ZSTD LOW compression to S3 on Pure Storage FlashBlade.
    ZSTD LOW provides faster compression with moderate space savings.
    Pure Storage's high throughput ensures optimal utilization of CPU resources
    for compression while eliminating storage bottlenecks.
*/
BACKUP DATABASE [TPCC] 
TO   URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC3_LOW_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC4_LOW_4.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = LOW), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - LOW level'
GO

/*
    Backup with ZSTD MEDIUM compression to S3 on Pure Storage FlashBlade.
    ZSTD MEDIUM balances compression ratio and speed for most workloads.
    Pure Storage FlashBlade's consistent performance enables predictable backup times
    regardless of compression level.
*/
BACKUP DATABASE [TPCC] 
TO   URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_4.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = MEDIUM), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - MEDIUM level'
GO

/*
    Backup with ZSTD HIGH compression to S3 on Pure Storage FlashBlade.
    ZSTD HIGH maximizes storage efficiency with higher CPU utilization.
*/
BACKUP DATABASE [TPCC] 
TO   URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_HIGH_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_HIGH_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_HIGH_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_HIGH_4.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = HIGH), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - HIGH level'
GO

------------------------------------------------------------
-- Step 5: Analyze backup performance and compression results
------------------------------------------------------------
/*
    Analyze the results of different backup methods.
    The combination of SQL Server 2025's ZSTD compression with Pure Storage FlashBlade
    provides industry-leading backup performance, enabling organizations to meet
    the most demanding RPO/RTO requirements even for very large databases.
*/
SELECT TOP 5
    bs.database_name AS DatabaseName,
    bs.backup_size / 1024 / 1024 AS BackupSizeMB,                                           -- Original size in MB
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS BackupRuntimeSeconds,  -- Runtime in seconds
    bs.compressed_backup_size / 1024 / 1024 AS CompressedSizeMB,                            -- Compressed size in MB
    CASE 
        WHEN bs.backup_size > 0 THEN 
            ((bs.backup_size - bs.compressed_backup_size) * 100 / bs.backup_size)           -- Compression percentage
        ELSE 
            NULL
    END AS CompressionPercentage,
    bs.description AS BackupDescription                                                     -- Backup description
FROM 
    msdb.dbo.backupset bs
ORDER BY 
    bs.backup_start_date DESC;

------------------------------------------------------------
-- Step 6: Test restore performance from Pure Storage FlashBlade
------------------------------------------------------------
/*
    Restore database from no-compression backup on Pure Storage FlashBlade.
    Pure Storage's consistent, high-throughput performance enables rapid database restores,
    minimizing downtime during recovery operations.
*/
RESTORE DATABASE [TPCC_NoCompression]
FROM 
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_1.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_2.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_3.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_NOCOMPRESSION_4.bak'
WITH 
    MOVE 'TPCC' TO 'D:\SQLDATA1\TPCC_NoCompression_Data.mdf',
    MOVE 'TPCC_Log' TO 'L:\SQLLOG\TPCC_NoCompression_Log.ldf',
    STATS = 25, REPLACE;
GO

/*
    Restore database from MS_XPRESS compression backup on Pure Storage FlashBlade.
    Even with traditional compression methods, Pure Storage's performance ensures
    optimal restore times for business-critical systems.
*/
RESTORE DATABASE [TPCC_MS_XPRESS]
FROM 
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_1.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_2.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_3.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MS_EXPRESS_4.bak'
WITH 
    MOVE 'TPCC' TO 'D:\SQLDATA1\TPCC_MS_XPRESS_Data.mdf',
    MOVE 'TPCC_Log' TO 'L:\SQLLOG\TPCC_MS_XPRESS_Log.ldf',
    STATS = 25, REPLACE;
GO

/*
    Restore database from ZSTD LOW compression backup on Pure Storage FlashBlade.
    The combination of SQL Server 2025's ZSTD compression with Pure Storage FlashBlade
    offers the ideal balance of storage efficiency and restore performance,
    dramatically improving recovery time objectives (RTOs).
*/
RESTORE DATABASE [TPCC_ZSTD_LOW]
FROM 
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_1.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_2.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC3_LOW_3.bak',
    URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC4_LOW_4.bak'
WITH 
    MOVE 'TPCC' TO 'D:\SQLDATA1\TPCC_ZSTD_LOW_Data.mdf',
    MOVE 'TPCC_Log' TO 'L:\SQLLOG\TPCC_ZSTD_LOW_Log.ldf',
    STATS = 25, REPLACE;
GO