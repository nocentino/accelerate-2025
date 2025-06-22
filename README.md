# SQL Server 2025 and Pure Storage Integration Demos

This repository contains a collection of demonstration scripts showcasing SQL Server 2025's new AI capabilities combined with Pure Storage infrastructure. These demos highlight various features including vector embeddings, semantic search, change tracking for AI operations, and efficient external storage management.

## Demos Overview

### Demo 1: Semantic Search on SQL Server 2025
- Vector embeddings with external AI models
- Semantic search using cosine similarity
- Vector indexing for faster performance
- Row-level security integration with AI workloads

### Demo 2a and 2b: FlashArray Snapshot Management
- Creating and managing Pure Storage FlashArray snapshots via T-SQL
- REST API integration for snapshot operations
- Snapshot metadata tagging and retrieval
- Metadata-only backup integration

### Demo 3: Performance Correlation Between SQL Server and Pure Storage
- Combining FlashArray metrics with SQL Server DMVs
- Correlating storage performance with database performance
- Identifying bottlenecks across the storage stack

### Demo 4: External Tables for Embedding Storage
- Using Pure Storage FlashBlade for tiering vector embeddings
- Configuring external data sources with S3-compatible storage
- Implementing data tiering strategies for AI workloads
- Optimizing vector search across tiered storage

## Prerequisites

- SQL Server 2025 with AI features enabled
- Pure Storage FlashArray and/or FlashBlade
- Properly configured network connectivity between SQL Server and Pure Storage
- Appropriate API tokens with sufficient permissions
- External model service (Ollama running on model-web server)
- Sample databases (AdventureWorks2025, StackOverflow_Embeddings)

## Usage

1. **Setup:**
   - Configure SQL Server with appropriate permissions
   - Enable external REST endpoints: `sp_configure 'external rest endpoint enabled', 1;`
   - Enable trace flags for vector operations: `DBCC TRACEON (466, 474, 13981, -1);`

2. **Run the demos:**
   - Execute each demo script sequentially
   - Review the comments for detailed explanation of each step
   - Observe the integration between SQL Server and Pure Storage

3. **Demo-specific notes:**
   - Demo 1: Requires Ollama model server for embedding generation
   - Demo 2: Requires valid Pure Storage API token
   - Demo 3: Shows correlation between SQL Server DMVs and Pure Storage metrics
   - Demo 4: Demonstrates tiering strategies for large embedding datasets

## Key Features Demonstrated

- **Vector Operations:** Creating, storing and searching embedding vectors
- **AI Integration:** Using external models with SQL Server
- **Pure Storage Integration:** REST API calls, snapshot management, performance monitoring
- **Enterprise Data Management:** Data tiering, archiving, and high-performance access
- **Security:** Row-level security with AI workloads

## Repository Structure

```
/sql-2025-and-pure-storage/
  ├── demo1.sql       # Semantic search capabilities
  ├── demo2a.sql      # Creating FlashArray snapshots
  ├── demo2b.sql      # Managing FlashArray snapshots
  ├── demo3.sql       # Performance correlation analysis
  ├── demo4.sql       # External table configurations
  └── README.md       # This documentation file
```

## Additional Resources

- [SQL Server 2025 Documentation](https://learn.microsoft.com/en-us/sql/sql-server/)
- [Pure Storage FlashArray REST API Guide](https://support.purestorage.com/bundle/m_purityfa_rest_api/page/FlashArray/PurityFA/Purity_FA_REST_API/topics/reference/r_flasharray_rest_api_reference_guides.html)
- [Vector Search in SQL Server](https://learn.microsoft.com/en-us/sql/relational-databases/vectors/vector-overview)
