# Kafka Broker - CDC Infrastructure

This directory contains Kafka broker configuration and testing for the CDC (Change Data Capture) pipeline in the data-sync-opensearch project.

## Overview

The Kafka broker provides the messaging backbone for CDC events, accepting change data from Debezium and distributing it to consumer applications with at-least-once delivery guarantees.

**Architecture:**
- PostgreSQL (logical replication) → Debezium Connect → **Kafka Topics** → Consumer Applications

**CDC Topics:**
- `dbserver.public.videos` (4,560 records)
- `dbserver.public.users` (391,277 records)
- `dbserver.public.comments` (500,000 records)

**Configuration:**
- Broker: Confluent Platform 7.6.0 (Kafka 3.6) in KRaft mode
- Delivery Mode: At-least-once (acks=all, retries enabled)
- Event Format: Debezium envelope (before/after/op/source/ts_ms)
- Monitoring: Kafka UI on port 8081

## Directory Structure

```
kafka/
├── tests/                          # Integration and validation tests
│   ├── performance/                # Performance benchmark scripts
│   │   ├── run-throughput-test.sh
│   │   ├── run-burst-test.sh
│   │   ├── run-sustained-load-test.sh
│   │   ├── run-snapshot-simulation.sh
│   │   ├── run-startup-test.sh
│   │   ├── collect-metrics.sh
│   │   └── generate-cdc-payload.sh
│   ├── delivery/                   # Delivery guarantee tests
│   │   ├── test-broker-restart.sh
│   │   ├── test-consumer-restart.sh
│   │   ├── test-network-partition.sh
│   │   ├── test-debezium-offset-recovery.sh
│   │   └── test-multiple-consumers.sh
│   ├── results/                    # Test outputs (gitignored)
│   ├── test-all-performance.sh     # Run all performance tests
│   ├── test-all-delivery.sh        # Run all delivery tests
│   ├── generate-reports.sh         # Generate markdown reports
│   ├── test-broker-health.sh       # Basic health check
│   ├── test-cdc-capture.sh         # CDC event verification
│   └── test-topic-creation.sh      # Topic creation test
├── quickstart.md                   # Quick start guide
└── README.md                       # This file
```

## Quick Start

Kafka is managed as part of the CDC infrastructure via Feature 002 (CDC Setup). Use CDC commands to control the Kafka broker:

### Start Kafka + CDC Services

```bash
# Start Kafka, Kafka UI, and Debezium Connect
make start-cdc
```

This command will:
1. Start Kafka broker (Confluent Platform 7.6.0)
2. Start Kafka UI on port 8081
3. Start Debezium Connect on port 8083
4. Wait for services to be ready
5. Automatically register the PostgreSQL connector

### Check Status

```bash
# Check connector and Kafka status
make status-cdc
```

### Monitor Kafka

**Via Kafka UI:**
- Open http://localhost:8081 in your browser
- View topics, messages, consumer groups, and broker metrics

**Via CLI:**
```bash
# List Kafka topics
docker compose exec kafka kafka-topics \
  --bootstrap-server localhost:9092 --list

# Consume CDC events
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.comments \
  --from-beginning --max-messages 5
```

### Stop CDC Services

```bash
# Stop Kafka, Kafka UI, and Debezium Connect
make stop-cdc
```

## Broker Configuration

### KRaft Mode (Single-Node Development)

Kafka runs in KRaft mode without ZooKeeper for simplified local development:

- **Process Roles**: `broker,controller` (combined mode)
- **Controller Quorum**: Single-node at `kafka:29093`
- **Listeners**:
  - `PLAINTEXT://kafka:9092` (client connections)
  - `CONTROLLER://kafka:29093` (controller protocol)

### At-Least-Once Delivery

Configured for reliable CDC event delivery:

- **Producer Settings** (Debezium):
  - `acks=all` (wait for all in-sync replicas)
  - `retries=2147483647` (retry indefinitely)
  - `max.in.flight.requests.per.connection=5`

- **Broker Settings**:
  - `min.insync.replicas=1` (development setting)
  - Replication factor: 1 (single broker)

- **Consumer Settings** (future):
  - `enable.auto.commit=false` (manual offset management)
  - `auto.offset.reset=earliest` (consume from beginning)

### Event Format

CDC events use the **Debezium envelope format** (no unwrap transformation):

```json
{
  "payload": {
    "before": null,
    "after": {
      "comment_id": "test-123",
      "video_id": "mcY4M9gjtsI",
      "comment_text": "Great video!",
      "updated_at": "2025-12-25T08:59:00Z"
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
- `before`: Previous row state (null for inserts)
- `after`: New row state (null for deletes)
- `op`: Operation type (`c`=create, `u`=update, `d`=delete, `r`=snapshot read)
- `source`: PostgreSQL metadata (database, schema, table, timestamp)
- `ts_ms`: Event timestamp

### Retention & Storage

- **Log Retention**: 7 days (time-based)
- **Segment Size**: 1GB
- **Compression**: lz4 (good balance of CPU vs. size)
- **Storage**: Docker volume `kafka_data`

## Integration Testing

Run integration tests to validate Kafka functionality:

```bash
# Test broker health
bash kafka/tests/test-broker-health.sh

# Test CDC event capture
bash kafka/tests/test-cdc-capture.sh

# Test topic creation
bash kafka/tests/test-topic-creation.sh
```

## Performance Validation

Feature 003 (Kafka Validation) provides comprehensive performance and delivery guarantee testing to validate that Kafka meets the operational requirements for CDC workloads.

### Running Tests

```bash
# Run performance benchmarks (throughput, burst, sustained load, snapshot, startup)
make test-kafka-performance

# Run delivery guarantee tests (broker restart, consumer restart, network partition, etc.)
make test-kafka-delivery

# Run all tests together
make test-kafka

# Generate performance and delivery reports
make kafka-reports
```

### Test Suites

**Performance Benchmarks** (5 tests):
1. **Throughput Test**: Validates ≥1000 msg/sec with <100ms p95 latency
2. **Burst Test**: Tests backpressure handling at 5000 msg/sec
3. **Sustained Load**: Validates stability over 5 minutes at 500 msg/sec
4. **Snapshot Simulation**: Replays 895K CDC events (initial snapshot simulation)
5. **Startup Test**: Measures broker cold start and warm restart time (<10s)

**Delivery Guarantee Tests** (5 tests):
1. **Broker Restart**: Verifies 0% message loss when broker restarts mid-stream
2. **Consumer Restart**: Validates offset recovery and no message gaps
3. **Network Partition**: Tests message delivery after 10s Kafka container pause
4. **Debezium Offset Recovery**: Validates CDC resumes from offset after connector restart
5. **Multiple Consumers**: Verifies independent consumer groups both receive all messages

### Interpreting Results

**Success Criteria**:
- All performance tests should **PASS** (meet throughput/latency thresholds)
- All delivery tests should **PASS** (0% message loss)

**Reports**:
- Performance baseline: `specs/003-kafka-validation/reports/performance-baseline.md`
- Delivery guarantees: `specs/003-kafka-validation/reports/delivery-guarantees.md`

**Troubleshooting Failed Tests**:
- Check test logs in `kafka/tests/results/`
- Review Docker container resource usage (CPU, memory)
- Verify Feature 002 (CDC Setup) is running: `make status-cdc`
- See test scripts for detailed failure reasons

### Manual Test Execution

Run individual tests directly:

```bash
# Performance tests
bash kafka/tests/performance/run-throughput-test.sh
bash kafka/tests/performance/run-burst-test.sh
bash kafka/tests/performance/run-sustained-load-test.sh
bash kafka/tests/performance/run-snapshot-simulation.sh
bash kafka/tests/performance/run-startup-test.sh

# Delivery tests
bash kafka/tests/delivery/test-broker-restart.sh
bash kafka/tests/delivery/test-consumer-restart.sh
bash kafka/tests/delivery/test-network-partition.sh
bash kafka/tests/delivery/test-debezium-offset-recovery.sh
bash kafka/tests/delivery/test-multiple-consumers.sh
```

See [specs/003-kafka-validation/](../specs/003-kafka-validation/) for full test specifications and implementation details.

## Troubleshooting

### Broker Not Starting

**Check Kafka logs:**
```bash
docker compose logs kafka --tail=100
```

**Common issues:**
1. Port 9092 already in use → Stop conflicting process
2. Insufficient disk space → Free up space or adjust retention
3. Memory limits → Increase Docker memory allocation (4GB recommended)

### No Messages in Topics

**Verify Debezium connector is running:**
```bash
make status-cdc
```

Both connector and task should show `RUNNING`.

**Check topic exists:**
```bash
docker compose exec kafka kafka-topics \
  --bootstrap-server localhost:9092 --list
```

**Manually insert test data:**
```bash
docker compose exec -T postgres psql -U app -d app -c "
INSERT INTO comments (comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code)
SELECT 'test-$(date +%s)', video_id, channel_id, 'Test CDC', 0, 0, NOW(), 'neutral', 'US'
FROM videos v, users u LIMIT 1;
"
```

Then check Kafka UI or consume from topic to verify event appears.

### Kafka UI Not Accessible

**Verify service is running:**
```bash
docker compose ps kafka-ui
```

**Check logs:**
```bash
docker compose logs kafka-ui --tail=50
```

**Access URL:**
- Local: http://localhost:8081
- If using Docker Desktop on Mac/Windows, ensure port is exposed

## Related Documentation

- [Debezium CDC Configuration](../debezium/README.md) - PostgreSQL connector setup
- [Feature 002: CDC Setup](../specs/002-cdc-setup/) - Complete CDC infrastructure specification
- [Feature 003: Kafka Validation](../specs/003-kafka-validation/) - Performance and delivery testing
- [Kafka Quickstart Guide](quickstart.md) - Step-by-step setup instructions

## Ports

| Service | Port | Description |
|---------|------|-------------|
| Kafka Broker | 9092 | Client connections (PLAINTEXT) |
| Kafka Controller | 29093 | KRaft controller protocol (internal) |
| Kafka UI | 8081 | Web monitoring interface |

## Next Steps

1. **Feature 003: Kafka Validation** - Run performance and delivery guarantee tests
2. **Feature 004: Consumer Application** - Build consumer to process CDC events and sync to OpenSearch
3. **Production Tuning** - Multi-broker cluster, replication factor 3, security (SSL/SASL)

For production deployment considerations, see [Feature 002 Implementation Plan](../specs/002-cdc-setup/plan.md).
