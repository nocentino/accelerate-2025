-- Demo 4 - Back up demo - perf numbers

-- No compression to NUL 
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH NO_COMPRESSION, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'No compression to NUL'
GO

-- MS_XPRESS (default) compression to NUL
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'Compression using MS_XPRESS (default) to NUL'
GO

-- ZSTD default compression to NUL
BACKUP DATABASE [TPCC] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION (ALGORITHM = ZSTD), 
     MAXTRANSFERSIZE = 4194304, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'Compression using ZSTD (default level) to NUL'
GO

-- No compression to S3
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

-- MS_XPRESS compression to S3
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

-- ZSTD LOW compression
BACKUP DATABASE [TPCC] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC2_LOW_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC3_LOW_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC4_LOW_4.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = LOW), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - LOW level'
GO

-- ZSTD MEDIUM compression
BACKUP DATABASE [TPCC] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TPCC_MED_4.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = MEDIUM), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 25, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - MEDIUM level'
GO

-- ZSTD HIGH compression
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

--
SELECT TOP 5
    bs.database_name AS DatabaseName,
    bs.backup_size / 1024 / 1024 AS BackupSizeMB, -- Original size in MB
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS BackupRuntimeSeconds, -- Runtime in seconds
    bs.compressed_backup_size / 1024 / 1024 AS CompressedSizeMB, -- Compressed size in MB
    CASE 
        WHEN bs.backup_size > 0 THEN 
            ((bs.backup_size - bs.compressed_backup_size) * 100 / bs.backup_size) -- Compression percentage
        ELSE 
            NULL
    END AS CompressionPercentage,
    bs.description AS BackupDescription -- Backup description

FROM 
    msdb.dbo.backupset bs
ORDER BY 
    bs.backup_start_date DESC;