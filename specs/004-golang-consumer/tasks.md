# Tasks: Golang CDC Consumer Application

**Input**: `/specs/004-golang-consumer/spec.md`
**Tests**: Unit and integration tests included

## Phase 1: Setup

- [ ] T001 Create consumer directory structure (consumer/cmd/, consumer/internal/, consumer/pkg/, consumer/tests/)
- [ ] T002 Initialize Go module (go mod init, add dependencies: sarama, opensearch-go)
- [ ] T003 Create Dockerfile for multi-stage build
- [ ] T004 [P] Create Makefile with targets (build, test, run, docker-build)

## Phase 2: Foundational

- [ ] T005 Create config.go in consumer/internal/config/ (load environment variables: Kafka brokers, OpenSearch URL, consumer group ID)
- [ ] T006 [P] Create logger.go in consumer/internal/logger/ (structured JSON logging with correlation IDs)
- [ ] T007 Create cdc_event.go in consumer/pkg/models/ (Debezium CDC event struct with before/after payload)
- [ ] T008 Create main.go in consumer/cmd/consumer/ (initialize app, graceful shutdown handling)

## Phase 3: User Story 1 - Consume CDC Events and Sync to OpenSearch (P1) 🎯 MVP

**Goal**: Consume Kafka CDC events, transform to OpenSearch documents, index with idempotent upserts

**Test**: Insert row in PostgreSQL, verify document appears in OpenSearch with correct data

### Unit Tests

- [ ] T009 [P] [US1] Create transform_test.go for video transformation (test CDC event → video document mapping)
- [ ] T010 [P] [US1] Create transform_test.go for user transformation
- [ ] T011 [P] [US1] Create transform_test.go for comment transformation

### Integration Tests

- [ ] T012 [US1] Create pipeline_test.go (end-to-end: PostgreSQL insert → Kafka event → OpenSearch document)

### Implementation

**Kafka Consumer**:

- [ ] T013 [US1] Create consumer.go in consumer/internal/kafka/ (Sarama consumer group setup, topic subscription)
- [ ] T014 [US1] Create handler.go in consumer/internal/kafka/ (message handler, call transformer based on topic)

**Transformation Logic**:

- [ ] T015 [P] [US1] Create video.go in consumer/internal/transform/ (parse CDC event, extract video fields, map to OpenSearch document)
- [ ] T016 [P] [US1] Create user.go in consumer/internal/transform/ (CDC → user document)
- [ ] T017 [P] [US1] Create comment.go in consumer/internal/transform/ (CDC → comment document)

**OpenSearch Indexer**:

- [ ] T018 [US1] Create client.go in consumer/internal/opensearch/ (initialize OpenSearch client with retry logic)
- [ ] T019 [US1] Create indexer.go in consumer/internal/opensearch/ (bulk indexing, idempotent upsert by document ID, error handling)

**Integration**:

- [ ] T020 [US1] Wire up consumer → transformer → indexer in main.go
- [ ] T021 [US1] Implement graceful shutdown (flush in-flight messages, commit offsets)
- [ ] T022 [US1] Add consumer service to docker-compose.yml (depends on Kafka, OpenSearch)
- [ ] T023 [US1] Test end-to-end: PostgreSQL insert → verify in OpenSearch
- [ ] T024 [US1] Run unit tests and integration test

**Checkpoint**: CDC events syncing to OpenSearch

## Phase 4: User Story 2 - Handle Failures and Ensure Reliable Delivery (P2)

**Goal**: Retry transient failures, dead letter queue for permanent failures, no data loss on restart

**Test**: Simulate OpenSearch unavailable, verify retries and DLQ; restart consumer, verify offset resume

### Integration Tests

- [ ] T025 [US2] Create test-failure-handling.sh (stop OpenSearch, produce event, verify retry then DLQ)
- [ ] T026 [US2] Create test-offset-resume.sh (restart consumer mid-processing, verify no duplicates/loss)

### Implementation

- [ ] T027 [US2] Add exponential backoff retry logic to indexer.go (configurable max retries)
- [ ] T028 [P] [US2] Implement dead letter queue producer (publish failed events to Kafka DLQ topic)
- [ ] T029 [US2] Add offset commit logic (commit only after successful OpenSearch index)
- [ ] T030 [US2] Test failure scenarios: OpenSearch down, malformed event, network error
- [ ] T031 [US2] Run integration tests for US2

**Checkpoint**: Reliable delivery with failure handling

## Phase 5: User Story 3 - Monitor Consumer Health and Performance (P3)

**Goal**: HTTP endpoints for health check and metrics (lag, throughput, errors)

**Test**: Call /health endpoint, verify status; call /metrics, verify lag and error counts

### Implementation

- [ ] T032 [US3] Create server.go in consumer/internal/health/ (HTTP server on :8080)
- [ ] T033 [P] [US3] Add /health endpoint (check Kafka connection, OpenSearch connection, consumer lag)
- [ ] T034 [P] [US3] Add /metrics endpoint (processing rate, error count, lag per partition)
- [ ] T035 [US3] Instrument consumer with metrics collection (increment counters, track latency)
- [ ] T036 [US3] Test health endpoints: call /health and /metrics, verify responses
- [ ] T037 [US3] Add structured logging for all operations (use correlation IDs from CDC events)

**Checkpoint**: Monitoring and observability complete

## Phase 6: Polish

- [ ] T038 [P] Create README.md in consumer/ directory (architecture, how to run, configuration)
- [ ] T039 [P] Add comprehensive error handling and input validation
- [ ] T040 Create quickstart.md for consumer setup and testing
- [ ] T041 [P] Add environment variable documentation to .env.example
- [ ] T042 Optimize performance: batch indexing, concurrent workers
- [ ] T043 Create integration test script that runs full pipeline test
- [ ] T044 Final validation: clean state, run consumer, verify all user stories working

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
- Requires Features 001 (PostgreSQL), 003 (Kafka), 005 (OpenSearch) running
- Feature 002 (Debezium) must be producing CDC events to Kafka
- US2 and US3 depend on US1 core functionality
