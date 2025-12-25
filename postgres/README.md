# PostgreSQL Datasource Setup

PostgreSQL database with normalized YouTube comment sentiment data for the data-sync-opensearch CDC pipeline.

## Overview

This PostgreSQL setup provides:
- **Normalized 3-table schema**: videos, users, comments
- **Sample dataset**: 500K records from Hugging Face youtube-comment-sentiment dataset
- **CDC-ready configuration**: WAL enabled for Debezium integration
- **Automated data loading**: Two-step setup with `make data` + `make start`

## Directory Structure

```
postgres/
├── Dockerfile                     # Custom PostgreSQL image
├── requirements.txt               # Python dependencies (datasets, pandas, psycopg2)
├── init/                          # SQL initialization scripts
│   ├── 01-create-schema.sql       # Create tables with foreign keys
│   └── 02-create-indexes.sql      # Create indexes for performance
├── scripts/                       # Data loading and management scripts (run via Makefile)
│   ├── download-dataset.py        # Download dataset from Hugging Face (runs in container)
│   ├── normalize-data.py          # Transform to 3-table structure (runs in container)
│   ├── load-csv-data.sh           # Load CSVs into PostgreSQL
│   ├── reset-database.sh          # Reset to clean state
│   ├── inspect-schema.sh          # View schema structure
│   ├── inspect-data.sh            # View sample data
│   └── wait-for-postgres.sh       # Health check helper
└── config/                        # PostgreSQL configuration
    └── postgresql.conf            # CDC-compatible WAL settings
```

## Docker Architecture

This setup uses a **multi-stage Docker build** for an optimized PostgreSQL image:

### Multi-Stage Build
**Stage 1 (dataset-builder)**:
- Uses Python 3.12 slim to download and normalize the dataset at build time
- Output: Pre-built CSV files (videos, users, comments)

**Stage 2 (final)**:
- Based on PostgreSQL 14 Alpine
- Copies only the CSV files from stage 1
- No Python runtime or build tools in final image

### Custom Image Features
- **Base**: PostgreSQL 14 Alpine
- **Dataset**: Pre-built CSVs baked into the image
- **Volume Mount**: `/var/lib/postgresql/sample-data` for data loading
- **Data**: Ephemeral container storage (no persisted volume)

### Build Process
```bash
# Multi-stage build (automatic with docker-compose)
docker compose build postgres
```

## Troubleshooting

- If the build fails during `pip install pandas` with `gcc` missing, ensure `postgres/requirements.txt` uses a pandas version with Python 3.12 wheels (2.1+), or add build tools to the dataset builder stage.
- If dataset download fails with `pyarrow` errors (`PyExtensionType`), upgrade `datasets` and `pyarrow` together so they share the same API generation.

### Why Multi-Stage?
- **Smaller image**: Build tools not included in final image
- **Deterministic data**: Dataset prepared at build time
- **Faster startup**: No runtime dataset download

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

### Build + First Start
1. **Build**: Dataset is downloaded and normalized into CSVs during image build
2. **Load**: `make start` (or `make load-data`) loads the CSVs via PostgreSQL COPY commands
3. **Verify**: Checks foreign key integrity and row counts

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
- **Comments**: ~500,000 comments
- **Total**: ~46,000-52,000 rows

## Related Services

This PostgreSQL datasource integrates with:
- **Feature 002**: Debezium CDC connector
- **Feature 003**: Kafka broker for CDC events
- **Feature 004**: Golang consumer application
- **Feature 005**: OpenSearch indices
