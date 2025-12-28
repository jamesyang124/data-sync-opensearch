# CDC Consumer Application

Golang-based consumer application that synchronizes CDC events from Kafka topics to OpenSearch indices with reliable delivery, failure handling, and observability.

## Architecture

```
PostgreSQL → Debezium → Kafka → Consumer (this app) → OpenSearch
```

The consumer reads Debezium CDC events from Kafka, transforms them to OpenSearch documents, and indexes them with idempotent upserts and optimistic locking.

## Features

- **CDC Event Processing**: Consumes INSERT/UPDATE/DELETE events from Kafka topics
- **Idempotent Operations**: Uses document IDs from primary keys for upsert operations
- **Optimistic Locking**: Compares `updated_at` timestamps to prevent stale writes
- **Backpressure Control**: Queue-based backpressure with automatic pause/resume when OpenSearch is overwhelmed
- **Failure Handling**: Exponential backoff retry with dead letter queue support
- **Health Monitoring**: HTTP endpoints for health checks and performance metrics
- **Structured Logging**: JSON logging with correlation IDs for tracing

## Project Structure

```
consumer/
├── cmd/consumer/         # Application entry point
├── internal/
│   ├── config/          # Configuration management
│   ├── kafka/           # Kafka consumer and handler
│   ├── opensearch/      # OpenSearch client and indexer
│   ├── transform/       # CDC event transformers
│   ├── health/          # Health check server
│   └── logger/          # Structured logging
├── pkg/models/          # Shared models (CDC events)
├── tests/               # Unit and integration tests
├── Dockerfile           # Multi-stage Docker build
├── Makefile             # Build and development commands
└── go.mod               # Go module dependencies
```

## Configuration

Configure via environment variables:

### Core Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `KAFKA_BROKERS` | Kafka broker addresses (comma-separated) | `localhost:9092` |
| `CONSUMER_GROUP` | Kafka consumer group ID | `cdc-consumer-group` |
| `OPENSEARCH_URL` | OpenSearch endpoint URL | `http://localhost:9200` |
| `HEALTH_PORT` | Health server port | `8080` |

### Advanced Configuration (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `BATCH_SIZE` | Batch size for indexing operations | `100` |
| `MAX_RETRIES` | Maximum retry attempts for failed operations | `3` |
| `WORKER_COUNT` | Number of concurrent worker goroutines | `10` |
| `QUEUE_SIZE` | Worker queue buffer size (messages) | `1000` |
| `PAUSE_THRESHOLD` | Pause consumption at X% queue utilization (0.0-1.0) | `0.8` (80%) |
| `RESUME_THRESHOLD` | Resume consumption at X% queue utilization (0.0-1.0) | `0.4` (40%) |

## Running Locally

### Prerequisites

- Go 1.24+
- Running Kafka with CDC topics
- Running OpenSearch cluster

### Build and Run

```bash
# Install dependencies
make deps

# Build binary
make build

# Run locally
make run

# Or run with environment variables
KAFKA_BROKERS=localhost:9092 OPENSEARCH_URL=http://localhost:9200 make run
```

### Docker

```bash
# Build Docker image
make docker-build

# Run container
make docker-run
```

## Testing

```bash
# Run unit tests
make test

# Run tests with coverage
make test-coverage
```

## Health Endpoints

### GET /health

Returns application health status including Kafka and OpenSearch connectivity.

**Response:**
```json
{
  "status": "healthy",
  "checks": {
    "kafka": { "connected": true },
    "opensearch": { "connected": true }
  },
  "uptime": "2h15m30s"
}
```

### GET /metrics

Returns consumer performance metrics including backpressure state.

**Response:**
```json
{
  "processing": {
    "total_processed": 15230,
    "error_count": 12,
    "success_rate": 99.92,
    "processing_rate": "125.50 events/sec",
    "last_processed": "2024-06-20T10:30:45Z"
  },
  "backpressure": {
    "queue_depth": 450,
    "queue_capacity": 1000,
    "queue_utilization": "45.0%",
    "is_paused": false,
    "pause_count": 3
  },
  "runtime": {
    "uptime_seconds": 8130,
    "start_time": "2024-06-20T08:15:15Z"
  }
}
```

## Topic-to-Index Mapping

| Kafka Topic | OpenSearch Index | Primary Key |
|------------|------------------|-------------|
| `dbserver.public.videos` | `videos_index` | `video_id` |
| `dbserver.public.users` | `users_index` | `channel_id` |
| `dbserver.public.comments` | `comments_index` | `comment_id` |

## Dead Letter Queue

Failed events are published to `{original_topic}.dlq` with error context for manual review and replay.

## Backpressure Control

The consumer implements queue-based backpressure to prevent overwhelming OpenSearch during high-throughput scenarios:

### How It Works

1. **Worker Pool**: Messages are submitted to a buffered queue (`QUEUE_SIZE`) processed by concurrent workers (`WORKER_COUNT`)
2. **Threshold Monitoring**: Queue utilization is continuously monitored
3. **Automatic Pause**: When queue reaches `PAUSE_THRESHOLD` (default 80%), Kafka consumption pauses
4. **Automatic Resume**: When queue drops to `RESUME_THRESHOLD` (default 40%), consumption resumes
5. **Hysteresis**: Dual thresholds prevent oscillation between paused/running states

### Monitoring Backpressure

Check backpressure state via `/metrics` endpoint:

```bash
curl http://localhost:8080/metrics | jq .backpressure
```

**Key metrics:**
- `queue_depth`: Current number of messages in worker queue
- `queue_utilization`: Percentage of queue capacity used
- `is_paused`: Whether consumption is currently paused
- `pause_count`: Total number of times consumption has paused

### Tuning Backpressure

Adjust backpressure behavior via environment variables:

```bash
# Increase queue size for bursty workloads
QUEUE_SIZE=2000

# More aggressive backpressure (pause earlier)
PAUSE_THRESHOLD=0.6

# Resume faster (at higher utilization)
RESUME_THRESHOLD=0.5

# More workers for higher throughput
WORKER_COUNT=20
```

**Recommendations:**
- **High throughput steady-state**: Increase `QUEUE_SIZE` and `WORKER_COUNT`
- **Memory constrained**: Decrease `QUEUE_SIZE`, lower `PAUSE_THRESHOLD`
- **Bursty traffic**: Larger gap between pause/resume thresholds (e.g., 0.8/0.3)

## Development

```bash
# Format code
go fmt ./...

# Run linter
golangci-lint run

# Clean build artifacts
make clean
```

## Dependencies

- **Kafka Client**: `github.com/IBM/sarama`
- **OpenSearch Client**: `github.com/opensearch-project/opensearch-go/v2`
- **Logging**: `go.uber.org/zap`

## License

See project root LICENSE file.
