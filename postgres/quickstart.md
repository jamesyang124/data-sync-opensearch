# PostgreSQL Datasource Quickstart

Get PostgreSQL running with sample data in under 3 minutes.

## Prerequisites

- Docker and Docker Compose installed
- Internet connection (for Docker image build and dataset download)
- **No Python required on host** (all dependencies packaged in Docker image)

**Note**: All Python dependencies are in `postgres/requirements.txt` and installed during image build.

## Quick Start

### 1. Build Custom PostgreSQL Image

```bash
# Build happens automatically with first `make start`
# Or build manually:
docker compose build postgres
```

**Note**: Dataset is downloaded at build time, not during container start.

### 2. Start PostgreSQL

```bash
make start
```

This command:
- Builds Docker image (if not already built)
- Starts PostgreSQL container
- Waits for database readiness
- Bulk loads data into PostgreSQL

**Expected time**:
- First run: 2-6 minutes (includes dataset download during build)
- Subsequent runs: 30 seconds (uses cached dataset)

**Note**: Database storage is ephemeral; data resets on container restart.

### 3. Verify Setup

```bash
make health
```

Expected output:
```
PostgreSQL Health Check:
=======================
✓ PostgreSQL is running

Database Statistics:
 schemaname | tablename |  size
------------+-----------+--------
 public     | comments  | 2048 kB
 public     | users     | 1024 kB
 public     | videos    | 512 kB
```

### 4. Inspect Data

View schema:
```bash
make inspect-schema
```

View sample records:
```bash
make inspect-data
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make start` | Start PostgreSQL and load sample data |
| `make load-data` | Load CSVs into PostgreSQL |
| `make stop` | Stop PostgreSQL container |
| `make health` | Check database status and table sizes |
| `make reset` | Reset database to clean state with fresh data |
| `make inspect-schema` | View table structures and foreign keys |
| `make inspect-data` | View first 10 rows from each table |
| `make logs` | View PostgreSQL container logs |

## Connecting to PostgreSQL

### Via psql

```bash
docker compose exec postgres psql -U app -d app
```

### Via Connection String

```
postgresql://app:app@localhost:5432/app
```

### Environment Variables

Default credentials (override in `.env` file):
```bash
POSTGRES_USER=app
POSTGRES_PASSWORD=app
POSTGRES_DB=app
POSTGRES_PORT=5432
```

## Sample Queries

### Count records per table
```sql
SELECT
  (SELECT COUNT(*) FROM videos) AS videos,
  (SELECT COUNT(*) FROM users) AS users,
  (SELECT COUNT(*) FROM comments) AS comments;
```

### Top videos by comment count
```sql
SELECT
  v.title,
  v.category,
  COUNT(c.comment_id) AS comment_count
FROM videos v
JOIN comments c ON v.video_id = c.video_id
GROUP BY v.video_id, v.title, v.category
ORDER BY comment_count DESC
LIMIT 10;
```

### Sentiment distribution
```sql
SELECT
  sentiment_label,
  COUNT(*) AS count
FROM comments
GROUP BY sentiment_label
ORDER BY count DESC;
```

## Troubleshooting

### Port 5432 already in use

```bash
# Stop existing PostgreSQL
make stop

# Or change port in .env file
echo "POSTGRES_PORT=5433" >> .env
make start
```

### Docker not running

```bash
# Start Docker Desktop or Docker daemon
# Then retry: make start
```

### Data loading failed

```bash
# Reset and reload
make reset
```

### Clear all data and volumes

```bash
docker compose down -v
make start
```

## Next Steps

1. Verify PostgreSQL is running: `make health`
2. Set up Debezium CDC connector (Feature 002)
3. Configure Kafka topics (Feature 003)
4. Run Golang consumer (Feature 004)
5. Query synced data in OpenSearch (Feature 005)

## Data Source

Dataset: [AmaanP314/youtube-comment-sentiment](https://huggingface.co/datasets/AmaanP314/youtube-comment-sentiment)

The dataset contains 1M+ YouTube comments. We use a 500K subset for local development while maintaining data diversity across video categories.
