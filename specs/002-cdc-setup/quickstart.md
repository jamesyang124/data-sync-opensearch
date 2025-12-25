# Debezium CDC Configuration - Quick Start Guide

This guide will walk you through setting up Change Data Capture (CDC) with Debezium to stream PostgreSQL changes to Kafka.

## Prerequisites

Before starting, ensure you have:

1. **Docker Desktop** installed and running
2. **PostgreSQL** from Feature 001 already running:
   ```bash
   make start
   ```
3. **Minimum 4GB RAM** allocated to Docker

## Step-by-Step Setup

### Step 1: Start CDC Services

Start Kafka, Kafka UI, and Debezium Connect:

```bash
make start-cdc
```

This command will:
1. Pull necessary Docker images (first time only):
   - `confluentinc/cp-kafka:7.6.0` (~600MB)
   - `debezium/connect:2.5` (~800MB)
   - `provectuslabs/kafka-ui:v0.7.2` (~200MB)
2. Start Kafka broker in KRaft mode
3. Start Kafka UI on port 8081
4. Start Debezium Connect on port 8083
5. Wait for services to be ready (~60 seconds)
6. Automatically register the PostgreSQL connector

**Expected output:**
```
Starting Debezium CDC services...
Waiting for services to be ready...
✓ Debezium services started

Registering PostgreSQL connector...
✓ Kafka Connect is ready
✓ Connector registered successfully

CDC Services:
  - Kafka Connect: http://localhost:8083
  - Kafka UI: http://localhost:8081
```

### Step 2: Verify Connector Status

Check that the connector is running:

```bash
make status-cdc
```

**Expected output:**
```json
{
  "name": "postgres-connector",
  "connector": {
    "state": "RUNNING",
    "worker_id": "172.18.0.5:8083"
  },
  "tasks": [
    {
      "id": 0,
      "state": "RUNNING",
      "worker_id": "172.18.0.5:8083"
    }
  ],
  "type": "source"
}

✅ Connector is healthy and running
```

Both `connector.state` and `tasks[0].state` should show `RUNNING`.

### Step 3: View Initial Snapshot

When the connector first starts, it takes a snapshot of existing data:

1. **Open Kafka UI**: http://localhost:8081
2. Navigate to **Topics**
3. You should see three CDC topics:
   - `dbserver.public.videos`
   - `dbserver.public.users`
   - `dbserver.public.comments`

**Expected snapshot sizes:**
- Videos: ~4,560 messages
- Users: ~391,000 messages
- Comments: ~500,000 messages

### Step 4: Test Real-Time CDC

Insert a test row and verify CDC captures it:

```bash
# Insert a test comment
docker compose exec -T postgres psql -U app -d app -c "
INSERT INTO comments (
  comment_id,
  video_id,
  channel_id,
  comment_text,
  likes,
  replies,
  published_at,
  sentiment_label,
  country_code
)
SELECT
  'quickstart-test-$(date +%s)',
  v.video_id,
  u.channel_id,
  'Testing CDC - this should appear in Kafka!',
  10,
  0,
  NOW(),
  'positive',
  'US'
FROM videos v, users u
LIMIT 1;
"
```

**Verify in Kafka UI:**
1. Go to http://localhost:8081
2. Click on **Topics** → `dbserver.public.comments`
3. Click **Messages**
4. You should see your test message at the top (newest first)

**Or verify via CLI:**
```bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.comments \
  --max-messages 1 \
  --from-beginning
```

### Step 5: Understand Event Format

CDC events use the default Debezium envelope format, which preserves full metadata:

```json
{
  "payload": {
    "before": null,
    "after": {
      "comment_id": "quickstart-test-1703498340",
      "video_id": "mcY4M9gjtsI",
      "channel_id": "UCxxxxxxxxx",
      "comment_text": "Testing CDC - this should appear in Kafka!",
      "likes": 10,
      "replies": 0,
      "published_at": "2025-12-25T09:00:00Z",
      "sentiment_label": "positive",
      "country_code": "US",
      "updated_at": "2025-12-25T09:00:00Z"
    },
    "op": "c",
    "source": {
      "db": "app",
      "schema": "public",
      "table": "comments",
      "ts_ms": 1703498340000
    },
    "ts_ms": 1703498340000
  }
}
```

**Key fields:**
- `before`: Previous row state (null for inserts, populated for updates/deletes)
- `after`: New row state (null for deletes, populated for inserts/updates)
- `op`: Operation type (`c`=create, `u`=update, `d`=delete, `r`=snapshot read)
- `source`: PostgreSQL metadata (database, schema, table, timestamp)
- `ts_ms`: Event timestamp from Debezium

## Common Operations

### View Connector Configuration

```bash
curl http://localhost:8083/connectors/postgres-connector/config | jq '.'
```

### Restart Connector

If you need to restart the connector (e.g., after config changes):

```bash
make restart-cdc
```

This will:
1. Delete the existing connector
2. Wait 3 seconds
3. Re-register with the same configuration
4. Resume from the last committed offset (no data loss)

### Stop CDC Services

When you're done:

```bash
make stop-cdc
```

This stops Kafka, Kafka UI, and Debezium Connect (but preserves offsets).

### Completely Clean Up

To remove all CDC data and start fresh:

```bash
# Stop services
make stop-cdc

# Remove volumes (WARNING: deletes offset data)
docker compose down -v

# Restart fresh
make start-cdc
```

## Monitoring and Debugging

### Check Service Health

**Kafka Connect:**
```bash
curl http://localhost:8083/ | jq '.'
```

**Connector Status:**
```bash
curl http://localhost:8083/connectors/postgres-connector/status | jq '.'
```

### View Connector Logs

```bash
docker compose logs connect --tail=100 -f
```

Look for:
- `Snapshot step` messages (initial snapshot progress)
- `RUNNING` state transitions
- Any `ERROR` or `WARN` messages

### Check Kafka Topics

```bash
docker compose exec kafka kafka-topics \
  --bootstrap-server localhost:9092 \
  --list
```

### Consume from Specific Offset

```bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.comments \
  --partition 0 \
  --offset 0 \
  --max-messages 10
```

## Troubleshooting

### Issue: Connector Not Starting

**Symptoms:**
- `make start-cdc` hangs or times out
- Connector state is `FAILED`

**Solutions:**

1. **Check PostgreSQL is running:**
   ```bash
   docker compose ps postgres
   ```
   If not running: `make start`

2. **Verify PostgreSQL is accepting connections:**
   ```bash
   docker compose exec -T postgres pg_isready -U app
   ```

3. **Check Connect logs:**
   ```bash
   docker compose logs connect --tail=50
   ```

4. **Verify PostgreSQL listen_addresses:**
   ```bash
   docker compose exec -T postgres psql -U app -d app -c "SHOW listen_addresses;"
   ```
   Should show `*` (not `localhost`)

### Issue: No Events in Kafka Topics

**Symptoms:**
- Topics exist but have no messages
- Snapshot not appearing

**Solutions:**

1. **Check connector is actually running:**
   ```bash
   make status-cdc
   ```
   Both connector and task should be `RUNNING`

2. **Check for connector errors:**
   ```bash
   curl http://localhost:8083/connectors/postgres-connector/status | jq '.tasks[0].trace'
   ```

3. **Verify replication slot exists:**
   ```sql
   docker compose exec -T postgres psql -U app -d app -c "
   SELECT slot_name, plugin, slot_type, active
   FROM pg_replication_slots
   WHERE slot_name = 'debezium_slot';
   "
   ```

4. **Restart connector to trigger new snapshot:**
   ```bash
   make restart-cdc
   ```

### Issue: High Lag or Slow Processing

**Symptoms:**
- Events taking >5 seconds to appear
- Kafka UI shows high consumer lag

**Solutions:**

1. **Check Kafka broker health:**
   ```bash
   docker compose logs kafka --tail=100
   ```

2. **Verify no resource constraints:**
   ```bash
   docker stats
   ```

3. **Tune connector settings** in `debezium/connectors/postgres-connector.json`:
   ```json
   {
     "max.batch.size": "4096",        // Increase from 2048
     "max.queue.size": "16384",       // Increase from 8192
     "poll.interval.ms": "500"        // Decrease from 1000
   }
   ```
   Then: `make restart-cdc`

### Issue: Kafka Connect Won't Start (ARM64/Apple Silicon)

**Symptoms:**
- Kafka crashes with `SIGILL` error
- Exit code 137 (OOM)

**Solution:**

This should already be fixed in docker-compose.yml (using Confluent Kafka 7.6.0), but if you see issues:

1. **Verify correct image:**
   ```bash
   grep "image: confluentinc/cp-kafka" docker-compose.yml
   ```
   Should show `confluentinc/cp-kafka:7.6.0`

2. **Check Docker resources:**
   - Docker Desktop → Settings → Resources
   - Ensure at least 4GB RAM allocated

## Next Steps

Now that CDC is working:

1. **Run Integration Tests:**
   ```bash
   bash debezium/tests/test-connector-registration.sh
   bash debezium/tests/test-cdc-capture.sh
   bash debezium/tests/test-offset-recovery.sh
   ```

2. **Explore Kafka UI:**
   - View topic messages and schemas
   - Monitor consumer groups and lag
   - Inspect connector configurations

3. **Build Consumer Application:**
   - Read from CDC topics
   - Process events
   - Sync to OpenSearch (Feature 003+)

4. **Learn More:**
   - [Debezium README](../../debezium/README.md)
   - [Implementation Plan](plan.md)
   - [Task List](tasks.md)

## Summary

You've successfully set up:
- ✅ Kafka broker with KRaft mode
- ✅ Debezium PostgreSQL connector
- ✅ Real-time CDC from 3 tables
- ✅ Kafka UI for monitoring
- ✅ 895K+ records in initial snapshot

**Key Commands:**
- `make start-cdc` - Start everything
- `make status-cdc` - Check health
- `make restart-cdc` - Restart connector
- `make stop-cdc` - Stop services

**Web Interfaces:**
- Kafka UI: http://localhost:8081
- Connect API: http://localhost:8083

Happy streaming! 🚀
