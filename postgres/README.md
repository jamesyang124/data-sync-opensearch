# PostgreSQL Datasource Setup

PostgreSQL database with normalized YouTube comment sentiment data for the data-sync-opensearch CDC pipeline.

## Overview

This PostgreSQL setup provides:
- **Normalized 3-table schema**: videos, users, comments
- **Sample dataset**: 30K records from Hugging Face youtube-comment-sentiment dataset
- **CDC-ready configuration**: WAL enabled for Debezium integration
- **Automated data loading**: One-command setup with `make start`

## Directory Structure

```
postgres/
├── Dockerfile                     # Custom PostgreSQL image with Python
├── requirements.txt               # Python dependencies (datasets, pandas, psycopg2)
├── init/                          # SQL initialization scripts
│   ├── 01-create-schema.sql       # Create tables with foreign keys
│   └── 02-create-indexes.sql      # Create indexes for performance
├── scripts/                       # Data loading and management scripts (copied into image)
│   ├── download-dataset.py        # Download dataset from Hugging Face (runs in container)
│   ├── normalize-data.py          # Transform to 3-table structure (runs in container)
│   ├── load-data.sh               # Orchestrate data loading (calls container scripts)
│   ├── reset-database.sh          # Reset to clean state
│   ├── inspect-schema.sh          # View schema structure
│   ├── inspect-data.sh            # View sample data
│   └── wait-for-postgres.sh       # Health check helper
├── sample-data/                   # Cached dataset files (mounted volume, gitignored)
│   ├── youtube-comments-raw.csv
│   ├── videos.csv
│   ├── users.csv
│   └── comments.csv
└── config/                        # PostgreSQL configuration
    └── postgresql.conf            # CDC-compatible WAL settings
```

## Docker Architecture

This setup uses a **multi-stage Docker build** for an optimized PostgreSQL image:

### Multi-Stage Build
**Stage 1 (python-builder)**:
- Builds Python dependencies (datasets, pandas, psycopg2)
- Uses full Python image with build tools
- Output: Compiled Python packages

**Stage 2 (final)**:
- Based on PostgreSQL 14 Alpine
- Copies only compiled Python packages from stage 1
- No build tools in final image → smaller image size
- Runtime dataset download on first start

### Custom Image Features
- **Base**: PostgreSQL 14 Alpine
- **Python 3.11**: Runtime only (no build dependencies)
- **Dependencies**: Pre-compiled from builder stage
- **Scripts**: Copied into `/usr/local/bin/postgres-scripts/`
- **Volume Mount**: `/var/lib/postgresql/sample-data` for dataset caching

### Build Process
```bash
# Multi-stage build (automatic with docker-compose)
docker compose build postgres

# Or manually
docker build -f postgres/Dockerfile -t data-sync-postgres .
```

### Why Multi-Stage?
- **Smaller image**: Build tools not included in final image
- **Faster builds**: Python packages cached in builder layer
- **Runtime download**: Dataset downloaded on first container start (avoids build memory issues)
- **Persistent cache**: Dataset cached in mounted volume, survives container restarts

## Schema Design

### Videos Table
Stores unique video records extracted from comments dataset.

```sql
CREATE TABLE videos (
    video_id VARCHAR(255) PRIMARY KEY,
    title TEXT NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Users Table
Stores unique user/channel records.

```sql
CREATE TABLE users (
    channel_id VARCHAR(255) PRIMARY KEY,
    channel_name VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Comments Table
Stores comment records with foreign keys to videos and users.

```sql
CREATE TABLE comments (
    comment_id VARCHAR(255) PRIMARY KEY,
    video_id VARCHAR(255) REFERENCES videos(video_id),
    channel_id VARCHAR(255) REFERENCES users(channel_id),
    comment_text TEXT NOT NULL,
    likes INTEGER DEFAULT 0,
    replies INTEGER DEFAULT 0,
    published_at TIMESTAMP,
    sentiment_label VARCHAR(50),
    country_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Data Loading Process

### First Container Start
1. **Check Cache**: Looks for existing dataset in `/var/lib/postgresql/sample-data/`
2. **Download** (if not cached): Fetches youtube-comment-sentiment from Hugging Face (30K subset, runs in container)
3. **Normalize**: Extracts unique videos and users, creates comments with foreign keys
4. **Cache**: Saves to mounted volume for future container starts
5. **Load**: Bulk inserts via PostgreSQL COPY command
6. **Verify**: Checks foreign key integrity and row counts

### Subsequent Starts
- Uses cached dataset from mounted volume (instant, no download)

## Configuration

PostgreSQL is configured with CDC-compatible settings for Debezium:

```conf
wal_level = logical
max_wal_senders = 4
max_replication_slots = 4
```

## Sample Data Statistics

Expected data distribution after loading:
- **Videos**: ~1,000-2,000 unique videos
- **Users**: ~15,000-20,000 unique channels
- **Comments**: ~30,000 comments
- **Total**: ~46,000-52,000 rows

## Related Services

This PostgreSQL datasource integrates with:
- **Feature 002**: Debezium CDC connector
- **Feature 003**: Kafka broker for CDC events
- **Feature 004**: Golang consumer application
- **Feature 005**: OpenSearch indices
