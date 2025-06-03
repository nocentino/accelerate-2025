
-- Demo 4 - Back up demo - perf numbers

-- No compression to NUL
BACKUP DATABASE [TPCC-500G] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH NO_COMPRESSION, 
     MAXTRANSFERSIZE = 4194304, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'No compression to NUL'
GO

WAITFOR DELAY '00:02:00';

-- MS_XPRESS (default) compression to NUL
BACKUP DATABASE [TPCC-500G] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION, 
     MAXTRANSFERSIZE = 4194304, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'Compression using MS_XPRESS (default) to NUL'
GO

WAITFOR DELAY '00:02:00';

-- ZSTD default compression to NUL
BACKUP DATABASE [TPCC-500G] 
TO DISK = 'nul', DISK = 'nul', DISK = 'nul', DISK = 'nul'
WITH COMPRESSION (ALGORITHM = ZSTD), 
     MAXTRANSFERSIZE = 4194304, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'Compression using ZSTD (default level) to NUL'
GO

WAITFOR DELAY '00:02:00';

-- No compression to S3
BACKUP DATABASE [TPCC-500G] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_4.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_5.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_6.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_7.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_8.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_9.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_10.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_11.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_12.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_13.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_14.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_15.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_NOCOMPRESSION_16.bak'
WITH NO_COMPRESSION, 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'No compression to S3'
GO

WAITFOR DELAY '00:02:00';

-- MS_XPRESS compression to S3
BACKUP DATABASE [TPCC-500G] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_4.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_5.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_6.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_7.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MS_EXPRESS_8.bak'
WITH COMPRESSION, 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'Compression using MS_XPRESS to S3'
GO

WAITFOR DELAY '00:02:00';

-- ZSTD LOW compression
BACKUP DATABASE [TPCC-500G] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB2_LOW_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB2_LOW_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB3_LOW_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB4_LOW_4.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB5_LOW_5.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB6_LOW_6.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB7_LOW_7.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB8_LOW_8.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = LOW), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - LOW level'
GO

WAITFOR DELAY '00:02:00';

-- ZSTD MEDIUM compression
BACKUP DATABASE [TPCC-500G] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_4.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_5.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_6.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_7.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_MED_8.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = MEDIUM), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - MEDIUM level'
GO

WAITFOR DELAY '00:02:00';

-- ZSTD HIGH compression
BACKUP DATABASE [TPCC-500G] 
TO URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_1.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_2.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_3.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_4.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_5.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_6.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_7.bak',
     URL = 's3://s200.fsa.lab/aen-sql-backups/TestDB_HIGH_8.bak'
WITH COMPRESSION (ALGORITHM = ZSTD, LEVEL = HIGH), 
     MAXTRANSFERSIZE = 20971520, 
     STATS = 10, INIT, FORMAT, 
     DESCRIPTION = 'ZSTD compression - HIGH level'
GO
