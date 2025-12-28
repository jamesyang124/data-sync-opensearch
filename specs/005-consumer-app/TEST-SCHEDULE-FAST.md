# Fast Test Execution - Feature 005 Consumer

**Duration**: 30-60 minutes
**Date**: ___________
**Tester**: ___________

---

## ⚡ Express Mode (30 minutes)

Run automated test suite:

```bash
cd /Users/murcurial/Coding/data-sync-opensearch

# Start infrastructure (2 min)
make start && sleep 30

# Run all tests in parallel (25 min)
bash specs/005-consumer-app/scripts/run-all-tests-fast.sh

# Review results (3 min)
cat test-results-summary.txt
```

**Result**: [ ] PASS [ ] FAIL

---

## 📋 Manual Mode (45-60 minutes)

### Minutes 0-5: Infrastructure Check

```bash
# Quick health check
make start
docker compose ps | grep -E "(healthy|running)" | wc -l  # Should be 5+
curl -s http://localhost:8080/health | jq -e '.status == "healthy"'
```

**Status**: [ ] PASS [ ] FAIL

---

### Minutes 5-10: Unit Tests (T024)

```bash
cd consumer
go test ./... -v -short  # Skip slow tests
```

**Result**: [ ] PASS [ ] FAIL
**Coverage**: ______%

---

### Minutes 10-25: E2E Pipeline Tests (T012, T023)

**Run smoke test script** (tests INSERT/UPDATE/DELETE):

```bash
./consumer/scripts/smoke-test.sh
```

**Additional: Optimistic Locking Test** (3 min):

```bash
# Insert record with T1
docker compose exec -T postgres psql -U app -d app << 'EOF'
INSERT INTO videos (video_id, user_id, title, updated_at)
VALUES ('lock_test', 'user1', 'Test', '2025-01-01 10:00:00');
EOF

sleep 3

# Update to T2
docker compose exec -T postgres psql -U app -d app << 'EOF'
UPDATE videos SET updated_at = '2025-01-01 11:00:00' WHERE video_id = 'lock_test';
EOF

sleep 3

# Verify current timestamp is T2
curl -s http://localhost:9200/videos_index/_doc/lock_test | \
  jq -e '._source.updated_at | contains("11:00:00")'
```

**E2E Results**:
- INSERT: [ ] PASS [ ] FAIL
- UPDATE: [ ] PASS [ ] FAIL
- DELETE: [ ] PASS [ ] FAIL
- Optimistic Lock: [ ] PASS [ ] FAIL

---

### Minutes 25-40: Failure Tests (T025, T026, T030, T031)

**Run in parallel** (open 3 terminals):

**Terminal 1: OpenSearch Failure Test** (5 min)
```bash
# Insert event
docker compose exec -T postgres psql -U app -d app << 'EOF'
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('fail_test_1', 'user1', 'Fail Test', 100, NOW(), NOW());
EOF

# Stop OpenSearch
docker compose stop opensearch

# Monitor retries for 60 seconds
docker compose logs consumer --tail=20 --follow &
sleep 60

# Restart and verify recovery
docker compose start opensearch
sleep 30
curl -s http://localhost:9200/videos_index/_doc/fail_test_1 | jq .found
# Expected: true
```

**Terminal 2: Restart/Offset Test** (5 min)
```bash
# Insert 3 records
for i in 1 2 3; do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('restart_$i', 'user1', 'Test $i', 100, NOW(), NOW());
EOF
done

sleep 5

# Stop consumer, insert 2 more
docker compose stop consumer
for i in 4 5; do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('restart_$i', 'user1', 'Test $i', 100, NOW(), NOW());
EOF
done

# Restart and verify all 5 indexed
docker compose start consumer
sleep 10
curl -s "http://localhost:9200/videos_index/_search?q=restart_*" | jq '.hits.total.value'
# Expected: 5
```

**Terminal 3: Malformed Event Test** (2 min)
```bash
# Send malformed event
docker compose exec kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos << 'EOF'
{"invalid": "malformed event without CDC structure"}
EOF

# Check DLQ (should appear within 30 seconds)
sleep 30
docker compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos.dlq \
  --from-beginning --max-messages 1 --timeout-ms 5000

# Verify consumer still healthy
curl http://localhost:8080/health | jq .status
```

**Failure Test Results**:
- OpenSearch failure/recovery: [ ] PASS [ ] FAIL (Recovery: ___s)
- Offset resume: [ ] PASS [ ] FAIL (Documents: ___/5)
- Malformed event: [ ] PASS [ ] FAIL (DLQ: [ ] YES [ ] NO)

---

### Minutes 40-50: Health, Metrics & Performance (T036, T042)

**Run validation script**:
```bash
./consumer/scripts/validate-deployment.sh
```

**Quick load test** (2 min):
```bash
# Insert 100 records rapidly
for i in $(seq 1 100); do
  docker compose exec -T postgres psql -U app -d app << EOF
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('perf_$i', 'user1', 'Test $i', 100, NOW(), NOW());
EOF
done

# Check throughput after 30 seconds
sleep 30
curl -s http://localhost:8080/metrics | jq '.processing.processing_rate'
curl -s http://localhost:8080/metrics | jq '.backpressure'
```

**Results**:
- Health endpoint: [ ] PASS [ ] FAIL (Response: ___ms)
- Metrics endpoint: [ ] PASS [ ] FAIL (Success rate: ___%)
- Throughput: _______ events/sec (target: ≥50)
- Backpressure triggered: [ ] YES [ ] NO

---

### Minutes 50-60: Final Validation (T043, T044)

**Quick checklist**:

```bash
# Verify all user stories
# US1: CDC Sync
curl -s "http://localhost:9200/videos_index/_count" | jq .
# Should have 100+ documents from previous tests

# US2: Failure Handling
# Already tested in Minutes 25-40

# US3: Monitoring
curl http://localhost:8080/health | jq .
curl http://localhost:8080/metrics | jq .
```

**Success Criteria Validation**:

| Criterion | Target | Result | Pass |
|-----------|--------|--------|------|
| SC-001: Latency | <10s | _____s | [ ] |
| SC-002: Throughput | 100/s | _____/s | [ ] |
| SC-003: No corruption | 0% | _____% | [ ] |
| SC-004: Recovery | <2min | _____s | [ ] |
| SC-005: Health response | <1s | _____ms | [ ] |
| SC-006: Success rate | 99.9% | _____% | [ ] |
| SC-007: Shutdown | <30s | _____s | [ ] |
| SC-008: Logs traceable | Yes | Yes/No | [ ] |

---

## 📊 Final Results

**Test Date**: _______________
**Duration**: _______ minutes
**Tester**: _______________

**Task Completion**:
- T024 (Unit tests): [ ] PASS [ ] FAIL
- T012, T023 (E2E): [ ] PASS [ ] FAIL
- T025, T026, T030, T031 (Failures): [ ] PASS [ ] FAIL
- T036 (Health/Metrics): [ ] PASS [ ] FAIL
- T042 (Performance): [ ] PASS [ ] FAIL
- T043, T044 (Integration): [ ] PASS [ ] FAIL

**Overall**: _____ / 12 tests passed

**Critical Issues**:
1. _______________________________________________
2. _______________________________________________

**Status**:
- [ ] ✅ READY FOR DEPLOYMENT
- [ ] ⚠️ NEEDS FIXES
- [ ] ❌ BLOCKED

---

## 🚀 Post-Test Actions

### Immediate:
```bash
# Mark tests complete in tasks.md
# Update tasks T024, T012, T023, T025, T026, T030-T031, T036, T042-T044

# Clean up test data
curl -X POST "http://localhost:9200/videos_index/_delete_by_query" \
  -H 'Content-Type: application/json' \
  -d '{"query": {"prefix": {"video_id": {"value": "test_"}}}}'
```

### Within 24 hours:
- [ ] Document results in test-results.md
- [ ] File issues for any bugs
- [ ] Update configuration based on findings
- [ ] Deploy to staging

---

## 💡 Tips for Speed

**Reduce Wait Times**:
- Use polling instead of fixed sleeps
- Run independent tests in parallel terminals
- Batch database inserts
- Skip redundant validations

**Automation**:
```bash
# Create helper function for polling
wait_for_index() {
  local doc_id=$1
  local max_wait=30
  for i in $(seq 1 $max_wait); do
    if curl -s "http://localhost:9200/videos_index/_doc/$doc_id" | jq -e '.found'; then
      echo "Document indexed after ${i}s"
      return 0
    fi
    sleep 1
  done
  echo "Timeout waiting for $doc_id"
  return 1
}

# Use it:
# Insert record
docker compose exec -T postgres psql ...
# Poll instead of sleep 10
wait_for_index "test_video_001"
```

**Parallel Execution**:
- Use `&` to background long-running tests
- Monitor all tests with `watch` command
- Collect results at end

---

**Optimized Schedule Created**: 2025-12-28
**Target Duration**: 30-60 minutes (vs 6.5 hours original)
**Time Savings**: 85-90%
