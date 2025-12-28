# Implementation Plan: Golang CDC Consumer Application

**Branch**: `005-consumer-app` | **Date**: 2025-12-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/005-consumer-app/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build Golang consumer application that reads Debezium envelope CDC events from Kafka topics (dbserver.public.videos, users, comments), transforms to OpenSearch documents, indexes with idempotent upserts, ignores stale updates via `updated_at`, handles failures with retries and dead letter queue, and exposes health/metrics endpoints.

**Technical Approach**: Golang with Sarama Kafka client (or Watermill), opensearch-go client, Debezium envelope parsing with optimistic lock on `updated_at`, goroutine worker pool for concurrency, structured JSON logging, HTTP server for health checks, Docker deployment.

## Technical Context

**Language/Version**: Golang 1.21+
**Primary Dependencies**: shopify/sarama (Kafka client), opensearch-project/opensearch-go (OpenSearch client), gorilla/mux or net/http (HTTP endpoints), uber-go/zap (structured logging)
**Storage**: No local storage (stateless consumer, offsets in Kafka)
**Testing**: Unit tests for transformation logic, integration tests for end-to-end pipeline
**Target Platform**: Docker container (Linux amd64)
**Project Type**: Single microservice (background consumer)
**Performance Goals**: 100 events/sec sustained throughput, <10s end-to-end latency (DB write → OpenSearch indexed)
**Constraints**: Single instance for development (no horizontal scaling yet)
**Scale/Scope**: 3 Kafka topics consumed, 3 OpenSearch indices targeted

## Constitution Check

✅ **ALL GATES PASSED**

- Plugin Architecture: Transformation logic per table type (extensible for new tables)
- Event-Driven Integration: Consumes Kafka events, produces OpenSearch indexes (**Kafka** → Consumer → **OpenSearch**)
- Integration Testing: End-to-end pipeline test (PostgreSQL write → OpenSearch read)
- Observability: Structured JSON logs with correlation IDs, health/metrics HTTP endpoints
- Docker-First: Deployed as Docker container

## Project Structure

```text
consumer/
├── cmd/
│   └── consumer/
│       └── main.go                    # Application entry point
├── internal/
│   ├── config/
│   │   └── config.go                  # Environment variable loading
│   ├── kafka/
│   │   ├── consumer.go                # Sarama consumer group setup
│   │   ├── handler.go                 # Message handler implementation
│   │   ├── handler_with_backpressure.go  # Backpressure-aware handler
│   │   └── worker_pool.go             # Worker pool with queue management
│   ├── opensearch/
│   │   ├── client.go                  # OpenSearch client wrapper
│   │   └── indexer.go                 # Bulk indexing logic
│   ├── transform/
│   │   ├── video.go                   # CDC → Video document
│   │   ├── user.go                    # CDC → User document
│   │   └── comment.go                 # CDC → Comment document
│   ├── health/
│   │   └── server.go                  # HTTP health/metrics server
│   └── logger/
│       └── logger.go                  # Structured logging setup
├── pkg/
│   └── models/
│       └── cdc_event.go               # CDC event struct
├── consumer/tests/
│   ├── unit/
│   │   └── transform_test.go          # Transformation unit tests
│   └── integration/
│       └── pipeline_test.go           # End-to-end pipeline test
├── Dockerfile                         # Multi-stage build
├── go.mod                             # Dependencies
└── Makefile                           # Build, test, run targets

docker-compose.yml                     # Add consumer service
consumer/tests/            # Integration tests
```

## Backpressure Control (IMPLEMENTED)

**Status**: ✅ Completed (T045)

The consumer implements queue-based backpressure to prevent overwhelming OpenSearch during high-throughput scenarios:

**Architecture**:
- **Worker Pool**: Buffered channel queue (`QUEUE_SIZE`) processed by concurrent goroutines (`WORKER_COUNT`)
- **Threshold Monitoring**: Continuous queue utilization tracking
- **Automatic Pause**: Kafka consumption pauses when queue reaches `PAUSE_THRESHOLD` (default 80%)
- **Automatic Resume**: Consumption resumes when queue drops to `RESUME_THRESHOLD` (default 40%)
- **Hysteresis**: Dual thresholds prevent oscillation between paused/running states

**Implementation Files**:
- `consumer/internal/kafka/worker_pool.go`: Worker pool with Submit() and ShouldResume() methods
- `consumer/internal/kafka/handler_with_backpressure.go`: Sarama handler with pause/resume logic
- `consumer/internal/config/config.go`: Environment variable configuration (QueueSize, PauseThreshold, ResumeThreshold)
- `consumer/internal/health/server.go`: Backpressure metrics exposure

**Configuration** (via environment variables):
```bash
QUEUE_SIZE=1000              # Worker queue buffer size (default: 1000)
WORKER_COUNT=10              # Concurrent workers (default: 10)
PAUSE_THRESHOLD=0.8          # Pause at 80% utilization (default: 0.8)
RESUME_THRESHOLD=0.4         # Resume at 40% utilization (default: 0.4)
```

**Metrics Exposed** (`/metrics` endpoint):
- `queue_depth`: Current messages in worker queue
- `queue_capacity`: Maximum queue size
- `queue_utilization`: Percentage of capacity used
- `is_paused`: Whether consumption is currently paused
- `pause_count`: Total times consumption paused

**Non-Destructive Design**: Messages not marked during pause, preventing data loss on pause/resume cycles.
