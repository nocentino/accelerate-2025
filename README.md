# SQL Server 2025 and Pure Storage Integration Demos

This repository contains a collection of demonstrations showcasing SQL Server 2025's powerful AI capabilities combined with Pure Storage's high-performance infrastructure. These demos span from vector search and embeddings to data tiering, snapshot management, and performance optimization techniques.

## Repository Structure

```
accelerate-2025/
│
├── enterprise-ai-for-operational-databases/
│   ├── demo2.sql - Exploring Embeddings and Storage in SQL Server
│   ├── demo3.sql - Using change events to drive AI outcomes
│   └── demo4.sql - Using external tables to store embeddings
│
└── sql-2025-and-pure-storage/
    ├── demo1.sql  - Semantic Search on SQL Server 2025
    ├── demo2a.sql - Using REST to take FlashArray snapshots
    ├── demo2b.sql - Retrieving and Managing FlashArray Snapshots
    ├── demo3.sql  - Combining FlashArray, DMVs, and performance data
    └── demo4.sql  - Backup Performance with ZSTD Compression
```

## Session - Accelerate Enterprise AI with Your SQL and Oracle Operational Databases

### Demo 2: Exploring Embeddings and Storage in SQL Server - [Video](https://youtu.be/lS3gzzG2rMs)
- Creating tables to store vector embeddings for StackOverflow posts
- Setting up dedicated filegroups for embedding data
- Generating embeddings with `AI_GENERATE_EMBEDDINGS`
- Performing similarity searches using vector distance functions
- Leveraging Pure Storage's data reduction for embeddings (3.5:1 average)

### Demo 3: Using Change Events to Drive AI Outcomes - [Video](https://youtu.be/-D1nHtjWM5w)
- Implementing Change Tracking to detect modified data
- Creating stored procedures to automatically update embeddings when source data changes
- Maintaining synchronization logs to track change versions
- Benefiting from Pure Storage's performance for real-time AI updates

### Demo 4: Using External Tables to Store Embeddings - [Video](https://youtu.be/5nJ0gi1KW4U)
- Configuring S3-compatible object storage with Pure FlashBlade
- Implementing data tiering strategies for embeddings
- Creating external tables for historical data
- Optimizing recent data access with in-database storage
- Providing a unified view across all data sources
- Vector indexing for optimized search performance
- Year-based partitioning for efficient data management

## Session - SQL Server 2025 & Pure Storage: AI, Performance, and Pure Storage Optimization


### Demo 1: Semantic Search on SQL Server 2025 - [Video](https://youtu.be/U3P_-0Mkxxg)
- Creating and testing external embedding models
- Adding vector columns to relational tables
- Generating embeddings for product data
- Performing semantic searches with vector distance functions
- Creating vector indexes for faster searches
- Implementing row-level security with AI workloads

### Demo 2a: Using REST to Take FlashArray Snapshots - [Video](https://youtu.be/7pEB6kWjVPg)
- Authenticating with Pure Storage FlashArray via REST API
- Using SQL Server's `SUSPEND_FOR_SNAPSHOT_BACKUP` feature
- Creating storage-level protection group snapshots
- Creating metadata-only backups referencing Pure Storage snapshots
- Tagging snapshots with comprehensive backup information
- Error handling and verification of snapshot creation

### Demo 2b: Retrieving and Managing FlashArray Snapshots - [Video](https://youtu.be/7pEB6kWjVPg?si=ls2rQFaBx_ErQ45j&t=138)
- Querying existing snapshots using REST API
- Filtering snapshots by SQL instance and database name
- Extracting snapshot metadata from tags
- Using JSON functions to parse and display snapshot information
- Reading backup headers from metadata-only backup files

### Demo 3: Combining FlashArray, DMVs, and Performance Data - [Video](https://youtu.be/CDhWxbgEy4A)
- Correlating Pure Storage metrics with SQL Server performance data
- Retrieving volume performance metrics via REST API
- Analyzing I/O statistics from `sys.dm_io_virtual_file_stats`
- Calculating volume-level latencies for reads and writes
- Comparing SQL Server's view with Pure Storage's metrics

### Demo 4: Backup Performance with ZSTD Compression - [Video](https://youtu.be/ct_ATivNqkU)
- Comparing backup performance with different compression algorithms
- Testing ZSTD compression at different levels (LOW, MEDIUM, HIGH)
- Backing up to Pure Storage FlashBlade via S3
- Analyzing backup compression ratios and performance
- Performing restores from compressed and uncompressed backups

## Prerequisites

- **SQL Server 2025** with AI features enabled
- **Pure Storage FlashArray and/or FlashBlade**
  - FlashArray for high-performance transactional workloads
  - FlashBlade for S3-compatible object storage
- **Network connectivity** between SQL Server and Pure Storage
- **API tokens** with appropriate permissions for Pure Storage REST API
- **External model service** (Ollama running on model-web server)
- **S3 credentials** for FlashBlade access
- **Sample databases** (AdventureWorks2025, StackOverflow_Embeddings, TPCC-4T)
- **Server configuration**:
  - External REST endpoint enabled: `sp_configure 'external rest endpoint enabled', 1;`
  - Vector feature trace flags: `DBCC TRACEON (466, 474, 13981, -1);`
  - PolyBase export enabled for external tables: `sp_configure 'allow polybase export', 1;`

## Key Features Demonstrated

- **Vector Operations:** Creating, storing, and searching embedding vectors
- **Pure Storage Integration:** REST API operations, snapshot management, performance monitoring
- **Enterprise Data Management:** Data tiering, backup compression, and high-performance access
- **AI-Enhanced Operations:** Change tracking with automatic AI updates, semantic search
- **Performance Optimization:** Index creation, data placement, and hybrid storage strategies
- **Security:** Row-level security with vector search capabilities

## Pure Storage Key Benefits

- **High Performance:** Sub-millisecond latency for database operations
- **Data Reduction:** Typically 2.5-3.5:1 for vector embeddings
- **Snapshot Efficiency:** Near-instant, zero-performance-impact snapshots
- **Backup & Recovery:** High-throughput S3 endpoints for rapid backup/restore
- **Hybrid Architecture:** Optimal data placement across FlashArray and FlashBlade
- **REST API Integration:** Comprehensive automation capabilities
- **Scalability:** Seamlessly scale from small to multi-petabyte deployments

