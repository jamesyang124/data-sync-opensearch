# Debezium CDC Configuration

This directory contains the Debezium PostgreSQL connector configuration for Change Data Capture (CDC) in the data-sync-opensearch project.

## Overview

The Debezium connector captures real-time changes from PostgreSQL and publishes them to Kafka topics, enabling event-driven data synchronization.

**Architecture:**
- PostgreSQL (logical replication) → Debezium Connect → Kafka Topics → Consumer Applications

**Monitored Tables:**
- `public.videos` (4,560 records)
- `public.users` (391,277 records)
- `public.comments` (500,000 records)

## Directory Structure

```
debezium/
├── connectors/
│   └── postgres-connector.json    # Connector configuration
├── scripts/
│   ├── register-connector.sh      # Register connector via REST API
│   ├── check-connector-status.sh  # Check connector health
│   ├── delete-connector.sh        # Remove connector
│   └── restart-connector.sh       # Restart connector (delete + re-register)
└── README.md                      # This file
```

## Quick Start

### 1. Start CDC Services

```bash
# Start Kafka, Kafka UI, and Debezium Connect
make start-cdc
```

This command will:
1. Start Kafka broker (Confluent Platform 7.6.0)
2. Start Kafka UI (http://localhost:8081)
3. Start Debezium Connect (http://localhost:8083)
4. Wait for services to be ready
5. Automatically register the PostgreSQL connector

### 2. Verify Connector Status

```bash
# Check connector health
make status-cdc
```

Expected output:
```json
{
  "name": "postgres-connector",
  "connector": {
    "state": "RUNNING",
    "worker_id": "..."
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "..."
    }
  ]
}
```

### 3. Monitor CDC Events

**Via Kafka UI:**
- Open http://localhost:8081 in your browser
- Navigate to Topics
- View topics: `dbserver.public.videos`, `dbserver.public.users`, `dbserver.public.comments`

**Via CLI:**
```bash
# List Kafka topics
docker compose exec kafka kafka-topics \
  --bootstrap-server localhost:9092 --list

# Consume events from comments topic
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.comments \
  --from-beginning --max-messages 5
```

## Connector Configuration

### Key Settings

Located in `connectors/postgres-connector.json`:

**Database Connection:**
```json
{
  "database.hostname": "postgres",
  "database.port": "5432",
  "database.user": "app",
  "database.dbname": "app"
}
```

**CDC Settings:**
```json
{
  "plugin.name": "pgoutput",              // PostgreSQL logical decoding
  "slot.name": "debezium_slot",           // Replication slot name
  "publication.name": "debezium_publication",
  "snapshot.mode": "initial"               // Take initial snapshot on first start
}
```

**Table Filtering:**
```json
{
  "table.include.list": "public.videos,public.users,public.comments",
  "schema.include.list": "public"
}
```

**Transforms:**
```json
{
  "transforms": "unwrap",
  "transforms.unwrap.type": "io.debezium.transforms.ExtractNewRecordState",
  "transforms.unwrap.add.fields": "op,source.ts_ms,source.table"
}
```

The `ExtractNewRecordState` transform extracts the actual row data from the Debezium envelope, making events easier to consume.

### Event Format

After transformation, CDC events look like:

```json
{
  "comment_id": "test-123",
  "video_id": "mcY4M9gjtsI",
  "channel_id": "UC...",
  "comment_text": "Great video!",
  "likes": 42,
  "replies": 3,
  "published_at": "2025-12-25T08:59:00Z",
  "sentiment_label": "positive",
  "country_code": "US",
  "__op": "c",                    // Operation: c=create, u=update, d=delete
  "__source_ts_ms": 1703498340000,
  "__source_table": "comments"
}
```

## Management Scripts

### Register Connector

```bash
# Register connector manually
bash debezium/scripts/register-connector.sh

# Or via Makefile
make register-connector
```

### Check Status

```bash
# Check connector health
bash debezium/scripts/check-connector-status.sh

# Or via Makefile
make status-cdc
```

### Restart Connector

```bash
# Restart connector (delete + re-register)
bash debezium/scripts/restart-connector.sh

# Or via Makefile
make restart-cdc
```

### Delete Connector

```bash
# Remove connector
bash debezium/scripts/delete-connector.sh
```

### Stop CDC Services

```bash
# Stop Kafka, Connect, and Kafka UI
make stop-cdc
```

## Troubleshooting

### Connector Not Starting

**Check Connect logs:**
```bash
docker compose logs connect --tail=100
```

**Common issues:**
1. PostgreSQL not reachable → Verify `make start` was run first
2. Kafka not ready → Wait 30-60 seconds after `make start-cdc`
3. Replication slot exists → Delete manually:
   ```sql
   SELECT pg_drop_replication_slot('debezium_slot');
   ```

### No Events in Kafka

**Verify connector is running:**
```bash
make status-cdc
```

**Check for errors:**
```bash
curl -s http://localhost:8083/connectors/postgres-connector/status | jq '.tasks[0].trace'
```

**Test with manual insert:**
```bash
docker compose exec -T postgres psql -U app -d app -c "
INSERT INTO comments (comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code)
SELECT 'test-$(date +%s)', video_id, channel_id, 'Test CDC', 0, 0, NOW(), 'neutral', 'US'
FROM videos v, users u LIMIT 1;
"
```

### Offset Issues

If connector keeps re-processing old data:

1. **Check offset topic:**
   ```bash
   docker compose exec kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic debezium_connect_offsets \
     --from-beginning --max-messages 10
   ```

2. **Reset connector (will re-snapshot):**
   ```bash
   make restart-cdc
   ```

## Performance Tuning

### Adjust Batch Sizes

In `connectors/postgres-connector.json`:

```json
{
  "max.batch.size": "2048",        // Events per batch (default: 2048)
  "max.queue.size": "8192",        // Internal queue size (default: 8192)
  "poll.interval.ms": "1000"       // Poll frequency (default: 1000ms)
}
```

### Snapshot Settings

```json
{
  "snapshot.mode": "initial",           // Options: initial, never, always
  "snapshot.fetch.size": "10000"        // Rows per snapshot fetch
}
```

For large tables, consider:
- Increase `snapshot.fetch.size` to reduce round trips
- Use `snapshot.mode: never` to skip snapshot (only capture new changes)

## Monitoring

### Key Metrics to Watch

1. **Connector State:** Should be `RUNNING`
2. **Task State:** Should be `RUNNING`
3. **Lag:** Check in Kafka UI under consumer groups
4. **Error Count:** Should be 0

### Kafka UI Dashboards

Access Kafka UI at http://localhost:8081:

- **Brokers:** View Kafka cluster health
- **Topics:** See topic sizes and partitions
- **Consumers:** Monitor lag and offset positions
- **Connect:** View connector status and configs

### Health Check Endpoint

```bash
# Connect health
curl http://localhost:8083/

# Connector status
curl http://localhost:8083/connectors/postgres-connector/status | jq '.'
```

## Integration Testing

Run integration tests to validate CDC functionality:

```bash
# Test connector registration
bash debezium/tests/test-connector-registration.sh

# Test CDC event capture
bash debezium/tests/test-cdc-capture.sh

# Test offset recovery after restart
bash debezium/tests/test-offset-recovery.sh
```

## Additional Resources

- [Debezium PostgreSQL Connector Docs](https://debezium.io/documentation/reference/stable/connectors/postgresql.html)
- [Kafka Connect REST API](https://docs.confluent.io/platform/current/connect/references/restapi.html)
- [Project Quickstart](../specs/002-debezium-setup/quickstart.md)

## Configuration Reference

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CONNECT_URL` | `http://localhost:8083` | Kafka Connect REST API URL |
| `CONNECTOR_NAME` | `postgres-connector` | Connector instance name |

### Ports

| Service | Port | Description |
|---------|------|-------------|
| Kafka Connect | 8083 | REST API endpoint |
| Kafka UI | 8081 | Web interface |
| Kafka Broker | 9092 | Kafka protocol |

## Next Steps

1. **Implement Consumer Application:** Process CDC events from Kafka topics
2. **Add Alerting:** Monitor connector health and set up alerts
3. **Scale Testing:** Test with higher volume workloads
4. **Production Config:** Review security, retention, and replication settings

For production deployment considerations, see [Production Deployment Guide](../specs/002-debezium-setup/plan.md#next-steps-for-production).
