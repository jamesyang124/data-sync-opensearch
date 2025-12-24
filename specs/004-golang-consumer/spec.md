# Feature Specification: Golang CDC Consumer Application

**Feature Branch**: `004-golang-consumer`
**Created**: 2025-12-25
**Status**: Draft
**Input**: User description: "consumer app would based on golang gin or any event driven frameworks"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consume CDC Events and Sync to OpenSearch (Priority: P1)

As a developer, I need a consumer application that reads CDC events from Kafka topics and synchronizes them to OpenSearch indices, so the video platform data becomes searchable and discoverable in near real-time.

**Why this priority**: This is the core sync functionality completing the end-to-end pipeline (PostgreSQL → Debezium → Kafka → Consumer → OpenSearch). Without this consumer, CDC events remain in Kafka with no downstream action.

**Independent Test**: Can be fully tested by producing CDC events to Kafka topics, running the consumer application, and verifying corresponding documents appear in OpenSearch indices with correct data. Delivers immediate value by making PostgreSQL data searchable.

**Acceptance Scenarios**:

1. **Given** Kafka topics contain CDC INSERT events for videos/users/comments, **When** consumer application starts, **Then** consumer reads events and creates corresponding documents in OpenSearch indices
2. **Given** Kafka contains UPDATE event for existing record, **When** consumer processes the event, **Then** consumer updates the corresponding OpenSearch document with new field values
3. **Given** Kafka contains DELETE event, **When** consumer processes the event, **Then** consumer removes the corresponding document from OpenSearch index

---

### User Story 2 - Handle Failures and Ensure Reliable Delivery (Priority: P2)

As a developer, I need the consumer to handle failures gracefully (OpenSearch unavailable, malformed events, network issues) with automatic retry and dead letter queue support, so the sync pipeline remains resilient and doesn't lose data.

**Why this priority**: Essential for operational reliability. The consumer must handle real-world failure scenarios, but basic sync functionality must work first (depends on P1).

**Independent Test**: Can be tested by simulating failures (stop OpenSearch, send invalid events, trigger network errors) and verifying consumer behavior matches configured retry policy and dead letter handling.

**Acceptance Scenarios**:

1. **Given** OpenSearch is temporarily unavailable, **When** consumer attempts to sync event, **Then** consumer retries with exponential backoff until OpenSearch recovers or max retries reached
2. **Given** consumer receives malformed CDC event, **When** event processing fails validation, **Then** consumer logs error details and moves event to dead letter queue without blocking other messages
3. **Given** consumer crashes mid-processing, **When** consumer restarts, **Then** consumer resumes from last committed Kafka offset without re-processing or skipping events

---

### User Story 3 - Monitor Consumer Health and Performance (Priority: P3)

As a developer, I need to monitor consumer application health, processing lag, error rates, and throughput metrics via HTTP endpoints and structured logs, so I can detect and diagnose issues before they impact search availability.

**Why this priority**: Important for observability but not required for basic sync operation. Developers can check logs manually as fallback.

**Independent Test**: Can be tested by accessing health check endpoint, querying metrics endpoint, and verifying they report consumer status, lag, and statistics correctly.

**Acceptance Scenarios**:

1. **Given** consumer is running and processing events, **When** developer calls health check endpoint, **Then** endpoint returns HTTP 200 with status showing consumer health, Kafka connectivity, and OpenSearch connectivity
2. **Given** consumer is processing CDC events, **When** developer queries metrics endpoint, **Then** endpoint returns processing rate, error count, lag per topic/partition, and OpenSearch indexing latency
3. **Given** consumer encounters errors, **When** developer checks structured logs, **Then** logs include correlation IDs, event details, error messages, and context for troubleshooting

---

### Edge Cases

- What happens when consumer processes events faster than OpenSearch can index? Consumer should apply backpressure by slowing down Kafka consumption to match OpenSearch throughput; if buffer fills, temporarily pause consumption.
- How does consumer handle duplicate CDC events (at-least-once delivery)? Consumer should use idempotent operations (upsert by document ID) so duplicates don't cause data corruption or unexpected behavior.
- What happens when OpenSearch index doesn't exist? Consumer should auto-create index with appropriate mapping on first document insertion, or fail with clear error if auto-creation is disabled.
- How does consumer handle schema evolution (new fields in CDC events)? Consumer should dynamically map new fields to OpenSearch documents; explicit mapping updates may be needed for type changes.
- What happens during consumer deployment/restart? Consumer should gracefully shut down by flushing in-flight batches, committing offsets, and allowing brief drain period before termination.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Application MUST consume CDC events from Kafka topics (dbserver.public.videos, dbserver.public.users, dbserver.public.comments) using consumer group for offset management
- **FR-002**: Application MUST transform CDC events (INSERT/UPDATE/DELETE operations) into corresponding OpenSearch operations (index/update/delete documents)
- **FR-003**: Application MUST use idempotent operations (upsert by document ID) to handle duplicate events from at-least-once delivery
- **FR-004**: Application MUST provide configurable mapping between Kafka topics and OpenSearch indices
- **FR-005**: Application MUST handle OpenSearch connection failures with exponential backoff retry (configurable max retries and backoff strategy)
- **FR-006**: Application MUST move malformed or repeatedly failing events to dead letter queue after exceeding retry limit
- **FR-007**: Application MUST commit Kafka offsets only after successful OpenSearch indexing to prevent data loss
- **FR-008**: Application MUST provide HTTP health check endpoint reporting consumer status, Kafka connectivity, and OpenSearch connectivity
- **FR-009**: Application MUST expose metrics endpoint providing processing rate, error count, lag per partition, and indexing latency
- **FR-010**: Application MUST emit structured JSON logs with correlation IDs for event tracing
- **FR-011**: Application MUST support graceful shutdown with configurable drain timeout for in-flight event processing
- **FR-012**: Application MUST load configuration from environment variables and optional configuration file
- **FR-013**: Application MUST deploy via Docker container with health checks and restart policies

### Key Entities

- **Consumer Application**: Event-driven service consuming Kafka CDC events and synchronizing to OpenSearch, using concurrent workers for parallel processing
- **CDC Event**: Structured message from Kafka containing operation type (INSERT/UPDATE/DELETE), table name, before/after state, and metadata (timestamp, transaction ID)
- **Document Transformation**: Logic converting CDC event payload to OpenSearch document format, extracting document ID, mapping field types, and handling nested structures
- **OpenSearch Index**: Search index storing documents with mappings, settings, and shards corresponding to PostgreSQL tables (videos_index, users_index, comments_index)
- **Consumer Group**: Kafka consumer group managing partition assignment, offset tracking, and rebalancing across multiple consumer instances
- **Dead Letter Queue**: Kafka topic or storage for events that failed processing after max retries, preserving original event and error context for manual review
- **Health Check**: HTTP endpoint exposing application health status including component connectivity (Kafka, OpenSearch), lag metrics, and error rates

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developer can deploy complete sync pipeline and see PostgreSQL changes reflected in OpenSearch within 10 seconds (end-to-end latency from database write to searchable document)
- **SC-002**: Consumer processes 100 CDC events per second sustained throughput without accumulating lag
- **SC-003**: Consumer handles duplicate events correctly with 0% data corruption (same event processed multiple times results in identical OpenSearch state)
- **SC-004**: Consumer recovers automatically from transient OpenSearch failures (<2 minutes downtime) without data loss or manual intervention
- **SC-005**: Health check endpoint responds within 1 second with accurate status for all components
- **SC-006**: Consumer achieves 99.9% successful event processing rate (0.1% to dead letter queue for truly malformed events)
- **SC-007**: Consumer graceful shutdown completes within 30 seconds, processing all in-flight events and committing offsets
- **SC-008**: Structured logs provide sufficient context to trace and debug 100% of processing errors

## Assumptions

- **A-001**: OpenSearch cluster is deployed and accessible from consumer application (separate from this feature scope)
- **A-002**: Kafka broker from feature 003 is running with configured topics and at-least-once delivery semantics
- **A-003**: CDC events from Debezium (feature 002) follow consistent JSON schema with operation type, table name, before/after payloads
- **A-004**: Consumer runs as single instance for development (horizontal scaling with multiple instances deferred to production)
- **A-005**: OpenSearch indices allow dynamic mapping for schema evolution (new fields added automatically)
- **A-006**: Document IDs can be derived from CDC event primary key fields (video_id, user_id/channel_id, comment_id)
- **A-007**: Consumer has sufficient memory to buffer events during backpressure scenarios without OOM errors
- **A-008**: Dead letter queue events are manually reviewed and replayed (no automatic retry from DLQ)
- **A-009**: Consumer application logs go to stdout/stderr for container log aggregation
- **A-010**: HTTP endpoints (health check, metrics) accessible on localhost without authentication for development

## Event Processing Recommendations

Based on event-driven architecture best practices and Golang ecosystem:

### Event-Driven Framework Options

**Option 1: Sarama + Goroutines (Recommended)**
- **Library**: shopify/sarama (mature Kafka client for Go)
- **Pattern**: Consumer group with worker pool of goroutines
- **Advantages**: Native Go concurrency, full Kafka control, no framework overhead
- **Complexity**: Manual worker management, offset tracking, graceful shutdown

**Option 2: Watermill**
- **Library**: ThreeDotsLabs/watermill (event-driven Go library)
- **Pattern**: Pub/sub abstraction with middleware support
- **Advantages**: Clean abstraction, middleware (retry, metrics, recovery), multiple backends
- **Complexity**: Additional abstraction layer, learning curve

**Option 3: Go-Micro**
- **Library**: asim/go-micro (microservices framework)
- **Pattern**: Full microservices framework with messaging
- **Advantages**: Comprehensive tooling, service discovery, observability built-in
- **Complexity**: Heavy framework, possibly overkill for single consumer

**Recommendation**: Sarama + Goroutines for direct control and performance, or Watermill if middleware patterns are valuable.

### HTTP Framework for Endpoints (Note: Gin mentioned but likely not needed)

**Important**: User mentioned "Gin or any event driven frameworks". However:
- **Gin**: HTTP web framework (for REST APIs) - likely NOT needed for consumer unless building admin API
- **Event-driven**: Consumer primarily needs Kafka client + background processing

**If HTTP endpoints required** (health check, metrics):
- **net/http** standard library: Sufficient for simple health/metrics endpoints
- **Gin/Echo/Chi**: Only if building more complex admin API alongside consumer

**Recommendation**: Start with net/http for minimal overhead; add Gin only if admin API requirements expand.

### OpenSearch Client

- **Library**: opensearch-project/opensearch-go (official Go client)
- **Operations**: Bulk API for batching, index/update/delete operations
- **Error Handling**: Retry transient errors (503, 429), DLQ for permanent failures (400, 404 on non-existent index)

### Concurrency Pattern

- **Consumer Goroutines**: 1-4 goroutines consuming from Kafka partitions (matches partition count)
- **Worker Pool**: Fixed pool processing events in parallel (e.g., 10-20 workers)
- **Batch Processing**: Group events into batches for OpenSearch bulk API (e.g., 100 events or 5 seconds)
- **Backpressure**: Block Kafka consumption if worker queue is full

### Configuration Approach

- **Environment Variables**: `KAFKA_BROKERS`, `OPENSEARCH_URL`, `CONSUMER_GROUP`, `BATCH_SIZE`, etc.
- **Config File** (optional): YAML or JSON for complex mapping rules
- **Defaults**: Sensible defaults for development (localhost:9092, localhost:9200)

## Out of Scope

- OpenSearch cluster deployment and configuration (separate infrastructure concern)
- Multiple consumer instances with partition rebalancing (single instance for development)
- Schema migration tooling for OpenSearch index mappings
- Complex event transformation logic (ETL operations beyond basic field mapping)
- Consumer admin UI for managing DLQ or replaying events
- Distributed tracing integration (OpenTelemetry/Jaeger)
- Performance benchmarking and load testing
- Production-grade monitoring dashboards (Grafana)
- Security (TLS for Kafka/OpenSearch, authentication, encryption at rest)

## References

- Sarama Kafka Client Documentation
- Watermill Event-Driven Library
- OpenSearch Go Client Documentation
- Kafka Consumer Group Protocol
- Graceful Shutdown Patterns in Go
