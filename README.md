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

### Demo 2: Exploring Embeddings and Storage in SQL Server - [Video](https://youtu.be/lS3gzzG2rMs) | [Code](enterprise-ai-for-operational-databases/demo2.sql)
This demo explores the implementation of vector storage in SQL Server using StackOverflow data. It walks through creating dedicated filegroups for embedding data and demonstrates how to generate vector embeddings using the `AI_GENERATE_EMBEDDINGS` function. The session shows practical similarity searches using vector distance functions while highlighting how Pure Storage achieves impressive data reduction ratios of approximately for these embedding workloads.

### Demo 3: Using Change Events to Drive AI Outcomes - [Video](https://youtu.be/-D1nHtjWM5w) | [Code](enterprise-ai-for-operational-databases/demo3.sql)
This demo showcases how Change Tracking in SQL Server can be leveraged to maintain up-to-date AI embeddings. It demonstrates the creation of stored procedures that automatically detect modified data and regenerate the corresponding embeddings. The session explains how to maintain synchronization logs to track change versions efficiently, highlighting how Pure Storage's performance characteristics enable these near real-time AI updates without impacting production workloads.

### Demo 4: Using External Tables to Store Embeddings - [Video](https://youtu.be/5nJ0gi1KW4U) | [Code](enterprise-ai-for-operational-databases/demo4.sql)
This demo presents a comprehensive data tiering strategy for managing large embedding datasets using Pure FlashBlade's S3-compatible object storage. It demonstrates configuring external tables for historical embeddings while keeping recent data in high-performance local storage. The session illustrates how to provide a unified view across all data sources and implement vector indexing for optimized searches, showing how this year-based partitioning approach maintains high performance while significantly reducing storage costs while maintaining performance.

## Session - SQL Server 2025 & Pure Storage: AI, Performance, and Pure Storage Optimization

### Demo 1: Semantic Search on SQL Server 2025 - [Video](https://youtu.be/U3P_-0Mkxxg) | [Code](sql-2025-and-pure-storage/demo1.sql)
This demo introduces SQL Server 2025's semantic search capabilities using vector embeddings. It walks through the process of creating and testing external embedding models, adding vector columns to relational tables, and generating embeddings for product data. The session demonstrates how to perform semantic searches using vector distance functions and create vector indexes for improved performance, while also highlighting how row-level security can be implemented alongside these AI workloads.

### Demo 2a: Using REST to Take FlashArray Snapshots - [Video](https://youtu.be/7pEB6kWjVPg) | [Code](sql-2025-and-pure-storage/demo2a.sql)
This demo showcases the integration between SQL Server 2025 and Pure Storage FlashArray using REST API calls. It demonstrates the authentication process and how to use SQL Server's `SUSPEND_FOR_SNAPSHOT_BACKUP` feature to create application-consistent snapshots. The session walks through the creation of metadata-only backups that reference Pure Storage snapshots, and shows how to implement comprehensive tagging and error handling for robust snapshot management. This demo enables you to find a snapshot by database name, rather than by volume name, bridging the gap between the database administrator and the storage administrator.

### Demo 2b: Retrieving and Managing FlashArray Snapshots - [Video](https://youtu.be/7pEB6kWjVPg?si=ls2rQFaBx_ErQ45j&t=138) | [Code](sql-2025-and-pure-storage/demo2b.sql)
A continuation of the previous demo, this demo focuses on the management of existing Pure Storage snapshots using SQL Server's REST capabilities. It demonstrates how to query and filter snapshots by SQL instance and database name, extract metadata from snapshot tags, and parse the information using SQL Server's JSON functions. The session also shows how to read backup headers from metadata-only backup files, completing the integration between SQL Server's backup catalog and Pure's snapshot system.

### Demo 3: Combining FlashArray, DMVs, and Performance Data - [Video](https://youtu.be/CDhWxbgEy4A) | [Code](sql-2025-and-pure-storage/demo3.sql)
This demo illustrates how to correlate Pure Storage performance metrics with SQL Server's Dynamic Management Views (DMVs). It shows techniques for retrieving volume performance metrics via REST API and analyzing I/O statistics from `sys.dm_io_virtual_file_stats`. The session demonstrates how to calculate volume-level latencies for reads and writes, providing a comprehensive comparison between SQL Server's perspective and Pure Storage's direct metrics for performance troubleshooting and optimization.

### Demo 4: Backup Performance with ZSTD Compression - [Video](https://youtu.be/ct_ATivNqkU) | [Code](sql-2025-and-pure-storage/demo4.sql)
This demo evaluates SQL Server 2025's ZSTD compression capabilities when backing up to Pure Storage FlashBlade. It compares performance across different compression algorithms and levels (LOW, MEDIUM, HIGH), demonstrating the trade-offs between compression ratio and backup time. The session includes analysis of both backup and restore performance, showing how the combination of ZSTD compression and Pure Storage's high-throughput S3 endpoints delivers optimal backup performance and storage efficiency.

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

