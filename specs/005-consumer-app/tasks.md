# Tasks: Golang CDC Consumer Application

**Input**: Design documents from `/specs/005-consumer-app/`
**Tests**: Unit and integration tests included

## Phase 1: Setup

- [X] T001 Create consumer directory structure (consumer/cmd/, consumer/internal/, consumer/pkg/, consumer/tests/)
- [X] T002 Initialize Go module (go mod init, add dependencies: sarama, opensearch-go, zap)
- [X] T003 Create Dockerfile for multi-stage build
- [X] T004 [P] Create Makefile with targets (build, test, run, docker-build)

## Phase 2: Foundational

- [X] T005 Create config.go in consumer/internal/config/ (load environment variables: Kafka brokers, OpenSearch URL, consumer group ID)
- [X] T006 [P] Create logger.go in consumer/internal/logger/ (structured JSON logging with zap and correlation IDs)
- [X] T007 Create cdc_event.go in consumer/pkg/models/ (Debezium CDC event struct with before/after payload)
- [X] T008 Create main.go in consumer/cmd/consumer/ (initialize app, graceful shutdown handling)

## Phase 3: User Story 1 - Consume CDC Events and Sync to OpenSearch (P1) 🎯 MVP

**Goal**: Consume Kafka CDC events, transform to OpenSearch documents, index with idempotent upserts

**Test**: Insert row in PostgreSQL, verify document appears in OpenSearch with correct data

### Unit Tests

- [X] T009 [P] [US1] Create transform_test.go for video transformation in consumer/tests/unit/ (test CDC event → video document mapping)
- [X] T010 [P] [US1] Create transform_test.go for user transformation in consumer/tests/unit/
- [X] T011 [P] [US1] Create transform_test.go for comment transformation in consumer/tests/unit/

### Integration Tests

- [ ] T012 [US1] Create pipeline_test.go in consumer/tests/integration/pipeline_test.go (end-to-end: PostgreSQL insert → Kafka event → OpenSearch document)

### Implementation

**Kafka Consumer**:

- [X] T013 [US1] Create consumer.go in consumer/internal/kafka/ (Sarama consumer group setup, topic subscription)
- [X] T014 [US1] Create handler.go in consumer/internal/kafka/ (message handler, call transformer based on topic)

**Transformation Logic**:

- [X] T015 [P] [US1] Create video.go in consumer/internal/transform/ (parse CDC event, extract video fields, derive OpenSearch _id from video_id, map to document)
- [X] T016 [P] [US1] Create user.go in consumer/internal/transform/ (CDC → user document, derive OpenSearch _id from user_id)
- [X] T017 [P] [US1] Create comment.go in consumer/internal/transform/ (CDC → comment document, derive OpenSearch _id from comment_id)

**OpenSearch Indexer**:

- [X] T018 [US1] Create client.go in consumer/internal/opensearch/ (initialize OpenSearch client with retry logic)
- [X] T019 [US1] Create indexer.go in consumer/internal/opensearch/ (bulk indexing, idempotent upsert by document ID)
- [X] T019a [US1] Implement optimistic locking in indexer.go (compare incoming updated_at with stored document; ignore if stale per FR-003a)

**Integration**:

- [X] T020 [US1] Wire up consumer → transformer → indexer in main.go
- [X] T021 [US1] Implement graceful shutdown (flush in-flight messages, commit offsets)
- [X] T022 [US1] Add consumer service to docker-compose.yml (depends on Kafka, OpenSearch)
- [ ] T012 [US1] Create pipeline_test.go in consumer/tests/integration/ (end-to-end test - deferred)
- [ ] T023 [US1] Test end-to-end: PostgreSQL insert → verify in OpenSearch (requires running system - deferred)
- [ ] T024 [US1] Run unit tests and integration test (requires running system - deferred)

**Checkpoint**: CDC events syncing to OpenSearch

## Phase 4: User Story 2 - Handle Failures and Ensure Reliable Delivery (P2)

**Goal**: Retry transient failures, dead letter queue for permanent failures, no data loss on restart

**Test**: Simulate OpenSearch unavailable, verify retries and DLQ; restart consumer, verify offset resume

### Integration Tests

- [ ] T025 [US2] Create test-failure-handling.sh (stop OpenSearch, produce event, verify retry then DLQ)
- [ ] T026 [US2] Create test-offset-resume.sh (restart consumer mid-processing, verify no duplicates/loss)

### Implementation

- [X] T027 [US2] Add exponential backoff retry logic to indexer.go (configurable max retries) - Already implemented in client.go
- [X] T028 [P] [US2] Implement dead letter queue producer (publish failed events to {topic}.dlq; preserve original payload + add error_context metadata)
- [X] T029 [US2] Add offset commit logic (commit only after successful OpenSearch index) - Implemented via session.MarkMessage() in handler.go
- [ ] T025-T026, T030-T031 [US2] Test tasks (deferred - require running system)

**Checkpoint**: Reliable delivery with failure handling

## Phase 5: User Story 3 - Monitor Consumer Health and Performance (P3)

**Goal**: HTTP endpoints for health check and metrics (lag, throughput, errors)

**Test**: Call /health endpoint, verify status; call /metrics, verify lag and error counts

### Implementation

- [X] T032 [US3] Create server.go in consumer/internal/health/ (HTTP server on :8080)
- [X] T033 [P] [US3] Add /health endpoint (check Kafka connection, OpenSearch connection, consumer lag)
- [X] T034 [P] [US3] Add /metrics endpoint (JSON response providing processing rate, error count, lag per partition)
- [X] T035 [US3] Instrument consumer with metrics collection (increment counters, track latency)
- [ ] T036 [US3] Test health endpoints: call /health and /metrics, verify responses (deferred - requires running system)
- [X] T037 [US3] Add structured logging with zap for all operations (use correlation IDs from CDC events) - Already implemented in T006

**Checkpoint**: Monitoring and observability complete

## Phase 6: Polish

- [X] T038 [P] Create README.md in consumer/ directory (architecture, how to run, configuration)
- [X] T039 [P] Add comprehensive error handling and input validation - Already implemented throughout
- [ ] T040 Create quickstart.md for consumer setup and testing - Already exists in specs/005-consumer-app/
- [X] T041 [P] Add environment variable documentation to .env.example
- [ ] T042 Optimize performance: batch indexing, concurrent workers (deferred - optimization task)
- [ ] T043 Create integration test script that runs full pipeline test (deferred - requires running system)
- [ ] T044 Final validation: clean state, run consumer, verify all user stories working (deferred - requires running system)

## Optional Enhancements

### Backpressure Control

- [X] T045 [OPTIONAL] Implement explicit backpressure mechanism (monitor worker queue depth, pause/resume Kafka consumption when threshold exceeded)

**Rationale**: Current implementation relies on blocking indexer calls to slow consumption. Explicit pause/resume provides more controlled backpressure for high-throughput scenarios.

**Implementation**:
1. Add worker queue depth monitoring to handler.go
2. Implement pause/resume logic using Sarama's `claim.Messages()` channel control
3. Add configurable thresholds (e.g., pause at 80% queue capacity, resume at 40%)
4. Expose queue depth metric in /metrics endpoint
5. Test with load scenario exceeding OpenSearch capacity

**Priority**: LOW - Current blocking approach is functional; this is an optimization for extreme load scenarios

---

## Summary

**Total Tasks**: 44
- Setup: 4
- Foundational: 4
- US1 (P1): 16 tasks - Core sync functionality
- US2 (P2): 7 tasks - Failure handling
- US3 (P3): 6 tasks - Monitoring
- Polish: 7

**Parallel**: 12 tasks marked [P]
**MVP**: 28 tasks (Setup + Foundational + US1)

**Dependencies**:
- Requires Features 001 (PostgreSQL), 003 (Kafka), 004 (OpenSearch) running
- Feature 002 (Debezium) must be producing CDC events to Kafka
- US2 and US3 depend on US1 core functionality
