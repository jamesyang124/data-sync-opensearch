# Test Execution Checklist: Golang CDC Consumer Application

**Purpose**: Systematic execution of all deferred test tasks once infrastructure is running
**Created**: 2025-12-28
**Feature**: [spec.md](../spec.md)
**Prerequisites**: PostgreSQL, Kafka, Debezium, OpenSearch, and Consumer services running

---

## Pre-Test Setup

### Infrastructure Verification

- [ ] **Postgres running**: `docker compose ps postgres` shows healthy
- [ ] **Kafka running**: `docker compose ps kafka` shows healthy
- [ ] **Debezium connector registered**: `curl http://localhost:8083/connectors/postgres-connector/status`
- [ ] **OpenSearch running**: `curl http://localhost:9200/_cluster/health`
- [ ] **Consumer running**: `docker compose ps consumer` shows healthy
- [ ] **Consumer health check passing**: `curl http://localhost:8080/health`

### Baseline Metrics

Record baseline before testing:
- [ ] Current processed count: `curl http://localhost:8080/metrics | jq .processing.total_processed`
- [ ] Current error count: `curl http://localhost:8080/metrics | jq .processing.error_count`
- [ ] Kafka consumer lag: `docker compose exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group cdc-consumer-group --describe`

---

## Phase 1: Unit Tests (T024)

**Task**: T024 - Run unit tests and verify transformation logic

### Steps

1. Navigate to consumer directory:
   ```bash
   cd consumer
   ```

2. Run unit tests:
   ```bash
   make test
   ```

3. Run tests with coverage:
   ```bash
   make test-coverage
   open coverage.html  # Review coverage report
   ```

### Success Criteria

- [ ] All unit tests pass (transform_video_test.go, transform_user_test.go, transform_comment_test.go)
- [ ] Test coverage > 80% for transformation logic
- [ ] No compilation errors or warnings

### Rollback

If tests fail:
- Review test failures in output
- Check CDC event structure matches data-model.md
- Verify helper functions (GetStringField, GetInt64Field) handle all data types

---

## Phase 2: End-to-End Pipeline Test (T023)

**Task**: T023 - PostgreSQL insert → verify in OpenSearch

### Steps

1. **Insert test video**:
   ```bash
   docker compose exec postgres psql -U app -d app -c "
   INSERT INTO videos (video_id, user_id, title, description, duration_seconds, view_count, like_count, created_at, updated_at)
   VALUES ('test_video_001', 'test_user_001', 'E2E Test Video', 'Testing CDC pipeline', 120, 0, 0, NOW(), NOW());
   "
   ```

2. **Wait for CDC propagation** (5-10 seconds):
   ```bash
   sleep 10
   ```

3. **Verify in OpenSearch**:
   ```bash
   curl -X GET "http://localhost:9200/videos_index/_doc/test_video_001?pretty"
   ```

4. **Update test video**:
   ```bash
   docker compose exec postgres psql -U app -d app -c "
   UPDATE videos SET view_count = 100, updated_at = NOW() WHERE video_id = 'test_video_001';
   "
   ```

5. **Wait and verify update**:
   ```bash
   sleep 10
   curl -X GET "http://localhost:9200/videos_index/_doc/test_video_001?pretty" | jq ._source.view_count
   # Expected: 100
   ```

6. **Delete test video**:
   ```bash
   docker compose exec postgres psql -U app -d app -c "
   DELETE FROM videos WHERE video_id = 'test_video_001';
   "
   ```

7. **Verify deletion**:
   ```bash
   sleep 10
   curl -X GET "http://localhost:9200/videos_index/_doc/test_video_001?pretty"
   # Expected: HTTP 404
   ```

### Success Criteria

- [ ] INSERT operation: Document appears in OpenSearch with correct fields
- [ ] UPDATE operation: Document updates with new view_count
- [ ] DELETE operation: Document removed from OpenSearch (404 response)
- [ ] End-to-end latency < 10 seconds (SC-001)
- [ ] Consumer metrics show processed count increased by 3

### Rollback

If test fails:
- Check consumer logs: `docker compose logs consumer --tail=100`
- Verify Kafka topics have messages: `docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver.public.videos --from-beginning --max-messages 5`
- Check Debezium connector status: `curl http://localhost:8083/connectors/postgres-connector/status`

---

## Phase 3: Integration Test - Pipeline (T012)

**Task**: T012 - Create and execute pipeline_test.go

### Steps

1. **Create integration test** (if not already created):
   ```bash
   # Test should be at consumer/tests/integration/pipeline_test.go
   # Should use testcontainers or existing docker-compose services
   ```

2. **Run integration test**:
   ```bash
   cd consumer
   go test -v ./tests/integration/... -timeout 2m
   ```

### Success Criteria

- [ ] Integration test creates test data in PostgreSQL
- [ ] Test verifies CDC events in Kafka
- [ ] Test confirms documents in OpenSearch
- [ ] Test validates optimistic locking (stale update ignored)
- [ ] Test completes within 2 minutes

### Rollback

Deferred until pipeline_test.go is created.

---

## Phase 4: Failure Handling Tests (T025, T026, T030, T031)

### T030 - Failure Scenarios

**Test 1: OpenSearch Down**

1. **Stop OpenSearch**:
   ```bash
   docker compose stop opensearch
   ```

2. **Insert test data**:
   ```bash
   docker compose exec postgres psql -U app -d app -c "
   INSERT INTO videos (video_id, user_id, title, description, duration_seconds, view_count, like_count, created_at, updated_at)
   VALUES ('test_failure_001', 'test_user_001', 'Failure Test', 'Testing retry logic', 60, 0, 0, NOW(), NOW());
   "
   ```

3. **Observe consumer logs** (should see retry attempts):
   ```bash
   docker compose logs consumer --tail=50 --follow
   # Look for: exponential backoff retry messages
   ```

4. **Wait for max retries** (~30 seconds)

5. **Verify DLQ topic**:
   ```bash
   docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver.public.videos.dlq --from-beginning --max-messages 1
   # Expected: Failed event with error context
   ```

6. **Restart OpenSearch**:
   ```bash
   docker compose start opensearch
   sleep 10
   ```

7. **Check health endpoint** (should recover):
   ```bash
   curl http://localhost:8080/health
   # Expected: opensearch.connected: true
   ```

**Success Criteria**:
- [ ] Consumer retries with exponential backoff (3 attempts visible in logs)
- [ ] Failed event published to DLQ after max retries
- [ ] Consumer recovers when OpenSearch restarts (SC-004: <2 min)
- [ ] No data loss or corruption

**Test 2: Malformed Event**

1. **Publish malformed event to Kafka**:
   ```bash
   echo '{"invalid": "json without required fields"}' | docker compose exec -T kafka kafka-console-producer --bootstrap-server kafka:9092 --topic dbserver.public.videos
   ```

2. **Check consumer logs**:
   ```bash
   docker compose logs consumer --tail=20
   # Expected: Error parsing CDC event, moved to DLQ
   ```

3. **Verify DLQ**:
   ```bash
   docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic dbserver.public.videos.dlq --from-beginning --max-messages 1
   # Expected: Malformed event with error_context
   ```

**Success Criteria**:
- [ ] Malformed event logged with error details
- [ ] Event moved to DLQ without blocking other messages
- [ ] Consumer continues processing subsequent events

### T026 - Offset Resume Test

1. **Record current offset**:
   ```bash
   docker compose exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group cdc-consumer-group --describe
   # Note current offset for dbserver.public.videos partition 0
   ```

2. **Insert test data**:
   ```bash
   docker compose exec postgres psql -U app -d app -c "
   INSERT INTO videos (video_id, user_id, title, description, duration_seconds, view_count, like_count, created_at, updated_at)
   VALUES ('test_offset_001', 'test_user_001', 'Offset Test 1', 'Testing offset resume', 60, 0, 0, NOW(), NOW());
   "
   ```

3. **Restart consumer mid-processing**:
   ```bash
   docker compose restart consumer
   ```

4. **Verify document created after restart**:
   ```bash
   sleep 10
   curl -X GET "http://localhost:9200/videos_index/_doc/test_offset_001?pretty"
   # Expected: Document exists with correct data
   ```

5. **Check offset not rewound**:
   ```bash
   docker compose exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group cdc-consumer-group --describe
   # Expected: Offset >= previous offset (no duplicates)
   ```

**Success Criteria**:
- [ ] Consumer resumes from last committed offset (T029 validation)
- [ ] No duplicate processing (same offset not re-consumed)
- [ ] No events skipped (all data appears in OpenSearch)
- [ ] Graceful shutdown completes within 30 seconds (SC-007)

### T025, T031 - Additional Integration Tests

Deferred until test scripts are created in consumer/tests/integration/.

---

## Phase 5: Health Endpoint Validation (T036)

**Task**: T036 - Test /health and /metrics endpoints

### Health Endpoint Tests

1. **Test healthy state**:
   ```bash
   curl -s http://localhost:8080/health | jq .
   ```

   **Expected Response**:
   ```json
   {
     "status": "healthy",
     "checks": {
       "kafka": { "connected": true },
       "opensearch": { "connected": true }
     },
     "uptime": "..."
   }
   ```

2. **Test degraded state** (Kafka down):
   ```bash
   docker compose stop kafka
   sleep 5
   curl -s http://localhost:8080/health | jq .
   # Expected: status: "degraded", kafka.connected: false, HTTP 503
   docker compose start kafka
   ```

3. **Response time test**:
   ```bash
   time curl -s http://localhost:8080/health > /dev/null
   # Expected: <1 second (SC-005)
   ```

### Metrics Endpoint Tests

1. **Test metrics response**:
   ```bash
   curl -s http://localhost:8080/metrics | jq .
   ```

   **Expected Response**:
   ```json
   {
     "processing": {
       "total_processed": ...,
       "error_count": ...,
       "success_rate": ...,
       "processing_rate": "... events/sec",
       "last_processed": "..."
     },
     "runtime": {
       "uptime_seconds": ...,
       "start_time": "..."
     }
   }
   ```

2. **Verify metrics accuracy**:
   - Insert 10 test records
   - Wait 15 seconds
   - Check `total_processed` increased by 10
   - Verify `success_rate` is 99%+ (SC-006)

3. **Check processing rate**:
   ```bash
   curl -s http://localhost:8080/metrics | jq .processing.processing_rate
   # Expected: ">= 100 events/sec" for sustained load (SC-002)
   ```

**Success Criteria**:
- [ ] /health returns correct status for all components
- [ ] /health responds within 1 second (SC-005)
- [ ] /health returns 503 when degraded
- [ ] /metrics shows accurate counters
- [ ] /metrics calculates correct success rate
- [ ] /metrics reports processing rate

---

## Phase 6: Final Validation (T043, T044)

### T043 - Integration Test Script

**Create full pipeline test script**:

```bash
#!/bin/bash
# consumer/tests/integration/run-full-pipeline-test.sh

set -e

echo "=== Full Pipeline Integration Test ==="

# 1. Clean state
echo "Cleaning test data..."
docker compose exec postgres psql -U app -d app -c "DELETE FROM videos WHERE video_id LIKE 'integration_test_%';"
sleep 5

# 2. Insert test data
echo "Inserting test data..."
for i in {1..10}; do
  docker compose exec postgres psql -U app -d app -c "
  INSERT INTO videos (video_id, user_id, title, description, duration_seconds, view_count, like_count, created_at, updated_at)
  VALUES ('integration_test_$i', 'test_user_001', 'Integration Test $i', 'Pipeline validation', 60, 0, 0, NOW(), NOW());
  "
done

# 3. Wait for propagation
echo "Waiting for CDC propagation..."
sleep 15

# 4. Verify in OpenSearch
echo "Verifying documents in OpenSearch..."
FOUND=0
for i in {1..10}; do
  if curl -s "http://localhost:9200/videos_index/_doc/integration_test_$i" | grep -q "integration_test_$i"; then
    FOUND=$((FOUND + 1))
  fi
done

echo "Found $FOUND/10 documents in OpenSearch"

if [ $FOUND -eq 10 ]; then
  echo "✅ Integration test PASSED"
  exit 0
else
  echo "❌ Integration test FAILED"
  exit 1
fi
```

**Success Criteria**:
- [ ] Script creates clean test state
- [ ] Script verifies all test data syncs
- [ ] Script reports clear pass/fail status

### T044 - Final Validation

**Complete validation checklist**:

1. **All user stories verified**:
   - [ ] US1: CDC events sync to OpenSearch ✅
   - [ ] US2: Failure handling with DLQ ✅
   - [ ] US3: Health monitoring endpoints ✅

2. **All success criteria met**:
   - [ ] SC-001: <10s end-to-end latency ✅
   - [ ] SC-002: 100 events/sec throughput ✅
   - [ ] SC-003: 0% data corruption ✅
   - [ ] SC-004: <2 min failure recovery ✅
   - [ ] SC-005: <1s health check ✅
   - [ ] SC-006: 99.9% success rate ✅
   - [ ] SC-007: <30s graceful shutdown ✅
   - [ ] SC-008: 100% error traceability ✅

3. **Production readiness**:
   - [ ] Consumer handles high load without OOM
   - [ ] Consumer recovers from all tested failure scenarios
   - [ ] DLQ contains only truly malformed events
   - [ ] Logs provide sufficient debug context
   - [ ] Metrics accurately reflect processing state

---

## Post-Test Cleanup

### Cleanup Test Data

```bash
# Remove test videos
docker compose exec postgres psql -U app -d app -c "DELETE FROM videos WHERE video_id LIKE 'test_%';"
docker compose exec postgres psql -U app -d app -c "DELETE FROM videos WHERE video_id LIKE 'integration_test_%';"

# Remove test documents from OpenSearch
curl -X POST "http://localhost:9200/videos_index/_delete_by_query?pretty" -H 'Content-Type: application/json' -d'
{
  "query": {
    "wildcard": {
      "video_id": "test_*"
    }
  }
}
'
```

### Reset Consumer State (Optional)

```bash
# Delete consumer group offsets (resets to beginning)
docker compose exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group cdc-consumer-group --delete
```

---

## Test Execution Summary

**Record final results**:

| Test Task | Status | Duration | Notes |
|-----------|--------|----------|-------|
| T024 - Unit tests | ⬜ | | |
| T023 - E2E pipeline | ⬜ | | |
| T012 - Integration test | ⬜ | | |
| T030 - Failure scenarios | ⬜ | | |
| T026 - Offset resume | ⬜ | | |
| T036 - Health endpoints | ⬜ | | |
| T043 - Full pipeline script | ⬜ | | |
| T044 - Final validation | ⬜ | | |

**Overall Status**: ⬜ PENDING / ✅ PASSED / ❌ FAILED

**Issues Found**: (List any failures or unexpected behavior)

**Follow-up Actions**: (Required fixes or optimizations)

---

**Test Execution Date**: ___________
**Tested By**: ___________
**Sign-off**: ___________
