# Test Execution Schedule - Feature 005 Consumer

**Scheduled Date**: To Be Determined
**Duration**: 30-60 minutes (optimized)
**Location**: Local development environment
**Prerequisites**: Docker Compose, all services configured

---

## Quick Start

**Choose your execution mode**:

### Option A: Express Testing (30 min) ⚡ RECOMMENDED
```bash
# Automated parallel execution
./specs/005-consumer-app/run-all-tests.sh
```

### Option B: Manual Step-by-Step (45-60 min)
```bash
# Follow detailed timeline below
# Includes parallel test execution
# More control over individual tests
```

### Option C: Smoke Test Only (5 min)
```bash
# Quick sanity check
./consumer/scripts/validate-deployment.sh
./consumer/scripts/smoke-test.sh
```

---

## Optimized 60-Minute Timeline

### 📅 Test Execution Plan

**Date**: ___________ (Fill in when scheduling)
**Start Time**: ___________
**Expected End**: ___________ (+60 minutes)

**Parallel Execution**: Tests run concurrently to maximize speed

---

### ⏰ Minutes 0-5 | Phase 0: Infrastructure Setup

**Duration**: 5 minutes
**Goal**: Verify all services running (automated)

**Checklist**:
```bash
# 9:00 - Start all services
cd /Users/murcurial/Coding/data-sync-opensearch
make start

# 9:05 - Verify services
docker compose ps
# Expected: All services showing "healthy" or "running"

# 9:10 - Check infrastructure health
make health
# Expected: PostgreSQL, Kafka, OpenSearch all responding

# 9:15 - Verify Debezium connector
make status-cdc
# Expected: Connector "RUNNING", tasks "RUNNING"

# 9:20 - Verify consumer
curl http://localhost:8080/health | jq .
# Expected: status "healthy", Kafka connected, OpenSearch connected

# 9:25 - Open monitoring terminals
# Terminal 1: docker compose logs consumer --follow
# Terminal 2: watch -n 5 'curl -s http://localhost:8080/metrics | jq .'
```

**Decision Point**:
- ✅ All services healthy → Proceed to Phase 1
- ❌ Services failing → Debug before proceeding

**Notes**:
_____________________________________________________________
_____________________________________________________________

---

### ⏰ 9:30 AM - 10:00 AM | Phase 1: Unit Tests

**Duration**: 30 minutes
**Task**: T024
**Goal**: Verify all unit tests pass

**Commands**:
```bash
# 9:30 - Navigate to consumer directory
cd consumer

# 9:35 - Run unit tests
go test ./internal/transform/... -v
go test ./tests/unit/... -v

# 9:45 - Run with race detector
go test -race ./...

# 9:50 - Generate coverage report
go test -cover ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
open coverage.html  # macOS
# OR: xdg-open coverage.html  # Linux
```

**Success Criteria**:
- [ ] All tests pass (0 failures)
- [ ] No data races detected
- [ ] Coverage ≥80% for transformation logic

**Results**:
- Tests passed: _____ / _____
- Coverage: ______%
- Issues found: _____________________________________________

**Decision Point**:
- ✅ All tests pass → Proceed to Phase 2
- ❌ Tests failing → Fix before proceeding

---

### ⏰ 10:00 AM - 11:00 AM | Phase 2: End-to-End Pipeline

**Duration**: 1 hour
**Tasks**: T012, T023
**Goal**: Validate complete CDC pipeline

#### 10:00 - 10:15 | Test 2.1: INSERT Operation

```bash
# Insert test video
docker compose exec -T postgres psql -U app -d app << 'EOF'
INSERT INTO videos (video_id, user_id, title, description, duration, created_at, updated_at)
VALUES (
  'test_video_001',
  'test_user_001',
  'Integration Test Video',
  'Testing CDC pipeline',
  300,
  NOW(),
  NOW()
);
EOF

# Wait for propagation
echo "Waiting 10 seconds for CDC propagation..."
sleep 10

# Verify in OpenSearch
curl -s http://localhost:9200/videos_index/_doc/test_video_001 | jq .

# Validate fields
curl -s http://localhost:9200/videos_index/_doc/test_video_001 | \
  jq -e '.found == true and ._source.title == "Integration Test Video"'
```

**Result**: [ ] PASS  [ ] FAIL
**Notes**: _____________________________________________________

#### 10:15 - 10:30 | Test 2.2: UPDATE Operation

```bash
# Update video title
docker compose exec -T postgres psql -U app -d app << 'EOF'
UPDATE videos
SET title = 'Updated Integration Test', updated_at = NOW()
WHERE video_id = 'test_video_001';
EOF

# Wait for propagation
sleep 10

# Verify update
curl -s http://localhost:9200/videos_index/_doc/test_video_001 | \
  jq -e '._source.title == "Updated Integration Test"'
```

**Result**: [ ] PASS  [ ] FAIL
**Notes**: _____________________________________________________

#### 10:30 - 10:45 | Test 2.3: DELETE Operation

```bash
# Delete video
docker compose exec -T postgres psql -U app -d app << 'EOF'
DELETE FROM videos WHERE video_id = 'test_video_001';
EOF

# Wait for propagation
sleep 10

# Verify deletion
curl -s http://localhost:9200/videos_index/_doc/test_video_001 | \
  jq -e '.found == false'
```

**Result**: [ ] PASS  [ ] FAIL
**Notes**: _____________________________________________________

#### 10:45 - 11:00 | Test 2.4: Optimistic Locking

```bash
# See test-execution.md Phase 2 for detailed steps
# Or use smoke-test.sh as reference
./consumer/scripts/smoke-test.sh
```

**Result**: [ ] PASS  [ ] FAIL
**Latency measured**: _______ seconds (target: <10s)

**Phase 2 Summary**:
- INSERT: [ ] PASS  [ ] FAIL
- UPDATE: [ ] PASS  [ ] FAIL
- DELETE: [ ] PASS  [ ] FAIL
- Optimistic Lock: [ ] PASS  [ ] FAIL

---

### ⏰ 11:00 AM - 12:00 PM | Phase 3: Failure Handling (Part 1)

**Duration**: 1 hour
**Tasks**: T025, T026, T030, T031

#### 11:00 - 11:30 | Test 3.1: OpenSearch Unavailable

```bash
# Insert record (event goes to Kafka)
docker compose exec -T postgres psql -U app -d app << 'EOF'
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('test_failure_001', 'user_001', 'Failure Test', 100, NOW(), NOW());
EOF

# Stop OpenSearch
docker compose stop opensearch
echo "OpenSearch stopped at $(date)"

# Monitor consumer logs for retry behavior
# Expected: Exponential backoff retry logs

# Wait 2 minutes, observe retries
sleep 120

# Restart OpenSearch
docker compose start opensearch
echo "OpenSearch restarted at $(date)"

# Wait for auto-recovery
sleep 30

# Verify event indexed
curl -s http://localhost:9200/videos_index/_doc/test_failure_001 | jq .found
```

**Result**: [ ] PASS  [ ] FAIL
**Recovery time**: _______ seconds (target: <120s)
**Notes**: _____________________________________________________

#### 11:30 - 12:00 | Test 3.2: Malformed Event Handling

```bash
# Produce malformed event to Kafka
docker compose exec kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos << 'EOF'
{"payload": "this is malformed JSON without proper CDC structure"}
EOF

# Monitor consumer logs for error handling
# Expected: Error logged, event moved to DLQ

# Check DLQ topic
docker compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos.dlq \
  --from-beginning \
  --max-messages 1 \
  --timeout-ms 10000

# Verify consumer continues processing
curl http://localhost:8080/health
# Expected: status still "healthy"
```

**Result**: [ ] PASS  [ ] FAIL
**Notes**: _____________________________________________________

---

### ⏰ 12:00 PM - 12:30 PM | 🍽️ LUNCH BREAK

**Take a 30-minute break. Services continue running.**

Optional: Run monitoring in background
```bash
./consumer/scripts/monitor-health.sh 10 &
```

---

### ⏰ 12:30 PM - 1:30 PM | Phase 3: Failure Handling (Part 2)

#### 12:30 - 1:00 | Test 3.3: Offset Resume After Restart

```bash
# Insert 5 records
for i in {1..5}; do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('restart_test_$i', 'user_001', 'Restart Test $i', 100, NOW(), NOW());
EOF
  sleep 2
done

# Wait for processing
sleep 15

# Verify 5 documents indexed
curl -s "http://localhost:9200/videos_index/_search?q=restart_test_*&size=10" | \
  jq '.hits.total.value'
# Expected: 5

# Stop consumer
docker compose stop consumer
echo "Consumer stopped at $(date)"

# Insert 3 more records (queued in Kafka)
for i in {6..8}; do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('restart_test_$i', 'user_001', 'Restart Test $i', 100, NOW(), NOW());
EOF
  sleep 1
done

# Restart consumer
docker compose start consumer
echo "Consumer restarted at $(date)"

# Wait for processing
sleep 20

# Verify all 8 documents indexed (no duplicates, no losses)
curl -s "http://localhost:9200/videos_index/_search?q=restart_test_*&size=10" | \
  jq '.hits.total.value'
# Expected: 8
```

**Result**: [ ] PASS  [ ] FAIL
**Documents indexed**: _____ / 8 expected
**Notes**: _____________________________________________________

#### 1:00 - 1:30 | Phase 3 Cleanup & Review

```bash
# Review all failure handling results
# Clean up test data
curl -X DELETE "http://localhost:9200/videos_index/_doc/test_failure_001"
curl -X DELETE "http://localhost:9200/videos_index/_search?q=restart_test_*"
```

**Phase 3 Summary**:
- OpenSearch unavailable: [ ] PASS  [ ] FAIL
- Malformed events: [ ] PASS  [ ] FAIL
- Offset resume: [ ] PASS  [ ] FAIL

---

### ⏰ 1:30 PM - 2:00 PM | Phase 4: Health & Metrics

**Duration**: 30 minutes
**Task**: T036

#### 1:30 - 1:45 | Test 4.1: Health Endpoint

```bash
# Test reachability and response time
time curl -s http://localhost:8080/health | jq .
# Expected: <1 second response time

# Test healthy state
curl -s http://localhost:8080/health | jq -e '.status == "healthy"'
curl -s http://localhost:8080/health | jq -e '.checks.kafka.connected == true'
curl -s http://localhost:8080/health | jq -e '.checks.opensearch.connected == true'

# Test degraded state
docker compose stop opensearch
sleep 5
curl -s http://localhost:8080/health | jq .status
# Expected: "degraded"

docker compose start opensearch
sleep 10
curl -s http://localhost:8080/health | jq .status
# Expected: "healthy" (recovered)
```

**Result**: [ ] PASS  [ ] FAIL
**Response time**: _______ ms (target: <1000ms)

#### 1:45 - 2:00 | Test 4.2: Metrics Endpoint

```bash
# Test metrics structure
curl -s http://localhost:8080/metrics | jq .

# Verify processing metrics
curl -s http://localhost:8080/metrics | jq '.processing'

# Verify backpressure metrics
curl -s http://localhost:8080/metrics | jq '.backpressure'

# Check success rate
curl -s http://localhost:8080/metrics | jq '.processing.success_rate'
# Expected: ≥99.0

# Verify metrics update over time
BEFORE=$(curl -s http://localhost:8080/metrics | jq '.processing.total_processed')
sleep 10
AFTER=$(curl -s http://localhost:8080/metrics | jq '.processing.total_processed')
echo "Processed $((AFTER - BEFORE)) events in 10 seconds"
```

**Result**: [ ] PASS  [ ] FAIL
**Success rate**: ______% (target: ≥99%)
**Notes**: _____________________________________________________

---

### ⏰ 2:00 PM - 3:00 PM | Phase 5: Performance Testing

**Duration**: 1 hour
**Task**: T042

#### 2:00 - 2:30 | Test 5.1: Throughput Baseline

```bash
# Generate 1000 test records
# See test-execution.md for detailed script
# Or use load generation script:

# Start monitoring
./consumer/scripts/monitor-health.sh 5 &
MONITOR_PID=$!

# Insert 1000 records over 60 seconds
for i in $(seq 1 1000); do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('perf_test_$i', 'user_001', 'Performance Test $i', 100, NOW(), NOW());
EOF
  [ $((i % 10)) -eq 0 ] && echo "Inserted $i records"
done

# Wait for processing
sleep 30

# Check throughput from metrics
curl -s http://localhost:8080/metrics | jq '.processing.processing_rate'

# Stop monitoring
kill $MONITOR_PID
```

**Result**: [ ] PASS  [ ] FAIL
**Throughput**: _______ events/sec (target: ≥100)
**Consumer lag**: _____________

#### 2:30 - 3:00 | Test 5.2: Backpressure Validation

```bash
# Generate burst of 500 events rapidly
for i in $(seq 1 500); do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('burst_test_$i', 'user_001', 'Burst Test $i', 100, NOW(), NOW());
EOF
done

# Monitor backpressure metrics
watch -n 1 'curl -s http://localhost:8080/metrics | jq ".backpressure"'

# Observe queue_utilization and is_paused
# Expected: is_paused becomes true when queue ≥80%
# Expected: is_paused becomes false when queue ≤40%
```

**Result**: [ ] PASS  [ ] FAIL
**Max queue utilization**: ______%
**Pause triggered**: [ ] YES  [ ] NO
**Resume triggered**: [ ] YES  [ ] NO
**Pause count**: _______

---

### ⏰ 3:00 PM - 4:00 PM | Phase 6: Final Integration

**Duration**: 1 hour
**Tasks**: T043, T044

#### 3:00 - 3:30 | Test 6.1: Automated Integration Script

```bash
# Run all validation scripts
./consumer/scripts/validate-deployment.sh > validation-results.txt
./consumer/scripts/smoke-test.sh > smoke-test-results.txt

# Review results
cat validation-results.txt
cat smoke-test-results.txt
```

**Result**: [ ] PASS  [ ] FAIL
**Tests passed**: _____ / _____
**Tests failed**: _____ / _____

#### 3:30 - 4:00 | Test 6.2: Final User Story Validation

```bash
# Clean state
curl -X DELETE "http://localhost:9200/videos_index"
docker compose restart consumer

# User Story 1: CDC Event Consumption
# - Insert, Update, Delete operations
# Expected: All operations work correctly

# User Story 2: Failure Handling
# - Retry logic, DLQ, offset resume
# Expected: All scenarios handled gracefully

# User Story 3: Monitoring
# - Health checks, metrics, logs
# Expected: All endpoints respond correctly
```

**User Story Results**:
- US1 (CDC Sync): [ ] PASS  [ ] FAIL
- US2 (Failures): [ ] PASS  [ ] FAIL
- US3 (Monitoring): [ ] PASS  [ ] FAIL

**Success Criteria Validation**:
- SC-001 (<10s latency): [ ] PASS  [ ] FAIL | Measured: _____s
- SC-002 (100 ev/sec): [ ] PASS  [ ] FAIL | Measured: _____/s
- SC-003 (0% corruption): [ ] PASS  [ ] FAIL
- SC-004 (<2min recovery): [ ] PASS  [ ] FAIL | Measured: _____s
- SC-005 (<1s health): [ ] PASS  [ ] FAIL | Measured: _____ms
- SC-006 (99.9% success): [ ] PASS  [ ] FAIL | Measured: _____%
- SC-007 (<30s shutdown): [ ] PASS  [ ] FAIL | Measured: _____s
- SC-008 (Traceable logs): [ ] PASS  [ ] FAIL

---

## 📊 Final Summary

**Test Execution Date**: _______________
**Total Duration**: _______ hours
**Tester(s)**: _______________

**Results Summary**:
- Total Tests: 12
- Tests Passed: _____
- Tests Failed: _____
- Tests Skipped: _____

**Success Criteria Met**: _____ / 8

**Critical Issues Found**: _____
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

**Overall Status**:
- [ ] ✅ READY FOR DEPLOYMENT
- [ ] ⚠️ NEEDS FIXES (list above)
- [ ] ❌ BLOCKED (explain): _______________________

---

## 📝 Post-Test Actions

### Immediate (Within 1 hour):
- [ ] Update tasks.md: Mark all test tasks as `[X]` completed
- [ ] Document results in test-results.md
- [ ] File GitHub issues for any bugs found
- [ ] Clean up test data from databases

### Within 1 day:
- [ ] Review logs for any warnings or errors
- [ ] Adjust configuration based on performance results
- [ ] Update README with any learnings
- [ ] Share results with team

### Within 1 week:
- [ ] Deploy to staging environment
- [ ] Set up continuous monitoring
- [ ] Create runbook for production issues
- [ ] Schedule follow-up performance tuning

---

## 🔗 References

- Detailed Procedures: [test-execution.md](checklists/test-execution.md)
- Validation Scripts: `consumer/scripts/`
- Spec Requirements: [spec.md](spec.md)
- Task Tracking: [tasks.md](tasks.md)

---

**Schedule Created**: 2025-12-28
**Ready to Execute**: When infrastructure is available
**Estimated Completion**: 1 day (6.5 hours active work)
