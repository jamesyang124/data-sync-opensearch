# Test Execution Schedule: Feature 005 Consumer Application

**Created**: 2025-12-28
**Feature**: Golang CDC Consumer Application
**Reference**: [test-execution.md](checklists/test-execution.md)

## Overview

This document provides a structured timeline for executing the 12 deferred test tasks that require running infrastructure. Tests are grouped by dependency and complexity to maximize efficiency.

**Total Deferred Tasks**: 12
**Estimated Total Duration**: 4-6 hours (including setup, execution, debugging)
**Prerequisites**: PostgreSQL, Debezium, Kafka, OpenSearch, Consumer all running via Docker Compose

---

## Test Execution Phases

### Phase 0: Infrastructure Setup (30 minutes)

**Goal**: Verify all infrastructure components are running and healthy

**Tasks**:
- [ ] Start all Docker Compose services (`make start`)
- [ ] Verify PostgreSQL accessible (`make health`)
- [ ] Verify Kafka brokers running (`docker compose logs kafka --tail=50`)
- [ ] Verify Debezium connector registered (`make status-cdc`)
- [ ] Verify OpenSearch cluster healthy (`curl http://localhost:9200/_cluster/health`)
- [ ] Verify consumer deployed (`docker compose ps consumer`)

**Success Criteria**: All services show `healthy` status

**Timeline**: Day 1, Morning (9:00 AM - 9:30 AM)

---

### Phase 1: Unit Tests (30 minutes)

**Task ID**: T024
**Goal**: Verify all unit tests pass with running infrastructure

**Commands**:
```bash
cd consumer
go test ./internal/transform/... -v
go test ./tests/unit/... -v
go test -race ./...
go test -cover ./... -coverprofile=coverage.out
go tool cover -html=coverage.out -o coverage.html
```

**Success Criteria**:
- All unit tests pass (0 failures)
- Race detector reports no data races
- Code coverage ≥80% for transformation logic

**Timeline**: Day 1, Morning (9:30 AM - 10:00 AM)

**Dependencies**: None (unit tests can run independently)

---

### Phase 2: End-to-End Pipeline Test (1 hour)

**Task IDs**: T012, T023
**Goal**: Validate complete CDC pipeline from PostgreSQL to OpenSearch

**Test Scenarios**:

1. **INSERT Operation** (15 minutes)
   - Insert video/user/comment record in PostgreSQL
   - Wait 10 seconds for CDC propagation
   - Verify document in OpenSearch with correct fields
   - Validate document ID matches primary key

2. **UPDATE Operation** (15 minutes)
   - Update existing record in PostgreSQL
   - Verify OpenSearch document reflects changes
   - Validate `updated_at` timestamp updated

3. **DELETE Operation** (15 minutes)
   - Delete record from PostgreSQL
   - Verify document removed from OpenSearch index

4. **Optimistic Locking Test** (15 minutes)
   - Create record with `updated_at = T1`
   - Update to `updated_at = T2`
   - Send stale event with `updated_at = T1.5` (between T1 and T2)
   - Verify OpenSearch document still shows T2 (stale update ignored)

**Success Criteria**: All 4 scenarios pass with <10s latency

**Timeline**: Day 1, Late Morning (10:00 AM - 11:00 AM)

**Dependencies**: Infrastructure running, Debezium producing events

**Reference**: Use `consumer/scripts/smoke-test.sh` as template

---

### Phase 3: Failure Handling Tests (1.5 hours)

**Task IDs**: T025, T026, T030, T031
**Goal**: Verify consumer handles failures gracefully

#### Test 3.1: OpenSearch Unavailable (30 minutes)

**Task**: T025 (partial), T030

**Steps**:
1. Insert record in PostgreSQL (event in Kafka)
2. Stop OpenSearch: `docker compose stop opensearch`
3. Observe consumer retry logs (exponential backoff)
4. Verify consumer doesn't crash
5. Start OpenSearch: `docker compose start opensearch`
6. Verify consumer auto-recovers and indexes event
7. Check DLQ topic is empty (no permanent failures)

**Success Criteria**:
- Consumer retries with exponential backoff
- Auto-recovery within 2 minutes after OpenSearch restart
- Event successfully indexed after recovery
- No data loss

**Timeline**: Day 1, Midday (11:00 AM - 11:30 AM)

#### Test 3.2: Malformed Event Handling (30 minutes)

**Task**: T025 (partial)

**Steps**:
1. Produce malformed JSON event to Kafka topic
2. Observe consumer error logs
3. Verify event moved to DLQ after max retries
4. Check consumer continues processing valid events
5. Inspect DLQ topic for malformed event with error context

**Success Criteria**:
- Consumer logs detailed error for malformed event
- Event moved to `{topic}.dlq` after 3 retries
- Consumer continues processing (no crash)
- DLQ event includes original payload + error metadata

**Timeline**: Day 1, Midday (11:30 AM - 12:00 PM)

#### Test 3.3: Offset Resume After Restart (30 minutes)

**Task**: T026, T031

**Steps**:
1. Insert 5 records in PostgreSQL (generate CDC events)
2. Verify consumer processes first 2 events
3. Stop consumer: `docker compose stop consumer`
4. Insert 3 more records (events queued in Kafka)
5. Start consumer: `docker compose start consumer`
6. Verify consumer resumes from last committed offset
7. Verify all 8 total records indexed (no duplicates, no losses)

**Success Criteria**:
- Consumer resumes from correct offset
- No duplicate indexing
- No event loss
- All 8 documents in OpenSearch

**Timeline**: Day 1, Early Afternoon (1:00 PM - 1:30 PM)

---

### Phase 4: Health & Metrics Validation (30 minutes)

**Task ID**: T036
**Goal**: Validate health and metrics endpoints

**Test 4.1: Health Endpoint** (15 minutes)

**Commands**:
```bash
# Test health endpoint reachability
curl -s http://localhost:8080/health | jq .

# Test response time (<1 second per SC-005)
time curl -s http://localhost:8080/health

# Test degraded state (stop OpenSearch)
docker compose stop opensearch
curl -s http://localhost:8080/health | jq .status  # Should return "degraded"
docker compose start opensearch
```

**Success Criteria**:
- Returns HTTP 200 when healthy
- Response time <1 second
- JSON includes `status`, `checks.kafka`, `checks.opensearch`, `uptime`
- Reports degraded when OpenSearch down
- Returns to healthy when OpenSearch recovers

**Timeline**: Day 1, Early Afternoon (1:30 PM - 1:45 PM)

**Test 4.2: Metrics Endpoint** (15 minutes)

**Commands**:
```bash
# Test metrics endpoint
curl -s http://localhost:8080/metrics | jq .

# Verify backpressure metrics
curl -s http://localhost:8080/metrics | jq .backpressure

# Verify processing metrics
curl -s http://localhost:8080/metrics | jq .processing

# Test success rate (should be ≥99% per SC-006)
curl -s http://localhost:8080/metrics | jq '.processing.success_rate'
```

**Success Criteria**:
- Returns HTTP 200
- JSON includes `processing`, `backpressure`, `runtime` sections
- `processing.total_processed` increases over time
- `processing.success_rate` ≥99%
- `backpressure.queue_depth` and `queue_utilization` present
- `processing_rate` shows events/sec throughput

**Timeline**: Day 1, Early Afternoon (1:45 PM - 2:00 PM)

---

### Phase 5: Performance & Load Testing (1 hour)

**Task ID**: T042
**Goal**: Validate throughput and backpressure behavior

**Test 5.1: Throughput Baseline** (30 minutes)

**Steps**:
1. Generate 1000 test records in PostgreSQL
2. Monitor consumer metrics for 60 seconds
3. Calculate sustained throughput (events/sec)
4. Verify consumer maintains target rate (100 events/sec per SC-002)
5. Check consumer lag doesn't accumulate

**Success Criteria**:
- Sustained throughput ≥100 events/sec
- Consumer lag stable or decreasing
- No backpressure triggered at normal load

**Timeline**: Day 1, Mid-Afternoon (2:00 PM - 2:30 PM)

**Test 5.2: Backpressure Validation** (30 minutes)

**Steps**:
1. Slow down OpenSearch (reduce resources or add artificial delay)
2. Generate burst of 500 events
3. Monitor `/metrics` endpoint for backpressure state
4. Verify `is_paused` becomes `true` when queue ≥80%
5. Verify consumption resumes when queue drops to ≤40%
6. Check `pause_count` increments

**Success Criteria**:
- Consumer pauses at 80% queue utilization
- Consumer resumes at 40% queue utilization
- No message loss during pause/resume cycles
- Backpressure metrics accurately reflect state

**Timeline**: Day 1, Mid-Afternoon (2:30 PM - 3:00 PM)

---

### Phase 6: Full Integration & Validation (1 hour)

**Task IDs**: T043, T044
**Goal**: Run complete end-to-end validation of all user stories

**Test 6.1: Integration Test Script** (30 minutes)

**Task**: T043

**Steps**:
1. Create automated integration test script combining all scenarios
2. Script should:
   - Start clean state (clear indices, reset offsets)
   - Run INSERT/UPDATE/DELETE scenarios
   - Validate failure handling
   - Check health/metrics endpoints
   - Verify performance targets
3. Generate test report with pass/fail results

**Success Criteria**:
- Automated script runs all tests
- Reports pass/fail for each scenario
- Generates summary statistics

**Timeline**: Day 1, Late Afternoon (3:00 PM - 3:30 PM)

**Test 6.2: Final User Story Validation** (30 minutes)

**Task**: T044

**Steps**:
1. Clean state: Drop all OpenSearch indices, reset Kafka offsets
2. Validate User Story 1 (CDC Event Consumption): Insert/Update/Delete operations
3. Validate User Story 2 (Failure Handling): OpenSearch down, malformed events, restart
4. Validate User Story 3 (Monitoring): Health checks, metrics, structured logs
5. Document any issues found

**Success Criteria**:
- All 3 user stories pass acceptance scenarios
- Success criteria (SC-001 through SC-008) validated
- No critical issues blocking deployment

**Timeline**: Day 1, Late Afternoon (3:30 PM - 4:00 PM)

---

## Test Execution Timeline Summary

| Phase | Tasks | Duration | Time Window | Prerequisites |
|-------|-------|----------|-------------|---------------|
| 0: Infrastructure Setup | Setup | 30 min | 9:00-9:30 AM | Docker Compose |
| 1: Unit Tests | T024 | 30 min | 9:30-10:00 AM | None |
| 2: E2E Pipeline | T012, T023 | 1 hour | 10:00-11:00 AM | Debezium events |
| 3: Failure Handling | T025, T026, T030-T031 | 1.5 hours | 11:00 AM-1:30 PM | Phase 2 complete |
| 4: Health/Metrics | T036 | 30 min | 1:30-2:00 PM | Consumer running |
| 5: Performance | T042 | 1 hour | 2:00-3:00 PM | Phase 4 complete |
| 6: Integration | T043, T044 | 1 hour | 3:00-4:00 PM | All phases complete |

**Total Duration**: 30-60 minutes (optimized for speed)

**Recommended Schedule**: Single session execution (30 min automated, or 60 min manual)

**⚡ NEW: Express Mode Available** - Run `specs/005-consumer-app/scripts/run-all-tests-fast.sh` for fully automated 30-minute execution.

---

## Validation Scripts Reference

Use these pre-built scripts to accelerate testing:

1. **Deployment Validation**: `consumer/scripts/validate-deployment.sh`
   - Tests health endpoint reachability, response time
   - Validates metrics structure
   - Checks success rate ≥99%

2. **Smoke Test**: `consumer/scripts/smoke-test.sh`
   - Quick E2E test (INSERT → verify → DELETE)
   - Validates CDC pipeline functional
   - Checks consumer metrics

3. **Health Monitoring**: `consumer/scripts/monitor-health.sh`
   - Continuous monitoring during tests
   - Real-time metrics display
   - Alerts on failures

**Usage**:
```bash
# Quick validation after deployment
./consumer/scripts/validate-deployment.sh

# E2E smoke test
./consumer/scripts/smoke-test.sh

# Monitor during load testing
./consumer/scripts/monitor-health.sh 5  # 5-second intervals
```

---

## Troubleshooting Guide

### Common Issues

**Issue**: Consumer not consuming events

**Debug Steps**:
```bash
# Check Debezium connector status
make status-cdc

# Check Kafka topic has messages
docker compose exec kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos \
  --from-beginning --max-messages 5

# Check consumer logs
docker compose logs consumer --tail=100 --follow
```

**Issue**: Events in Kafka but not in OpenSearch

**Debug Steps**:
```bash
# Check consumer processing logs
docker compose logs consumer | grep "Processing message"

# Check for indexing errors
docker compose logs consumer | grep -i error

# Verify OpenSearch accessible
curl http://localhost:9200/_cat/indices
```

**Issue**: Tests failing intermittently

**Common Causes**:
- CDC propagation delay (increase wait time from 10s to 15s)
- OpenSearch indexing delay (add refresh after writes)
- Kafka rebalancing (wait for stable consumer group)
- Resource contention (reduce concurrent services)

---

## Test Execution Checklist

Use this checklist during test execution:

### Pre-Test Checklist
- [ ] All Docker services running (`docker compose ps`)
- [ ] Debezium connector active (`make status-cdc`)
- [ ] OpenSearch cluster green (`curl localhost:9200/_cluster/health`)
- [ ] Consumer healthy (`curl localhost:8080/health`)
- [ ] Test data scripts available (`postgres/sample-data/`)

### During-Test Checklist
- [ ] Monitor consumer logs in separate terminal
- [ ] Track metrics endpoint during load tests
- [ ] Document test results for each phase
- [ ] Capture error logs for failed scenarios
- [ ] Take screenshots of metrics dashboards

### Post-Test Checklist
- [ ] All test tasks marked complete in tasks.md
- [ ] Test results documented
- [ ] Known issues logged (if any)
- [ ] Performance metrics recorded
- [ ] Cleanup: Stop services or leave running for monitoring

---

## Success Criteria Validation Mapping

| Success Criterion | Validation Method | Test Phase |
|-------------------|-------------------|------------|
| SC-001: <10s latency | Measure PostgreSQL write → OpenSearch search | Phase 2 |
| SC-002: 100 events/sec | Monitor metrics during load test | Phase 5 |
| SC-003: 0% corruption | Duplicate event test, verify identical state | Phase 2 |
| SC-004: Auto-recovery <2min | OpenSearch down/up test | Phase 3 |
| SC-005: Health <1s response | Time curl command | Phase 4 |
| SC-006: 99.9% success rate | Check metrics endpoint | Phase 4 |
| SC-007: <30s shutdown | Test graceful shutdown | Phase 6 |
| SC-008: Traceable errors | Review structured logs | Phase 3 |

---

## Next Steps After Test Completion

1. **Update tasks.md**: Mark all test tasks as `[X]` completed
2. **Document Results**: Create test-results.md with findings
3. **Log Issues**: File GitHub issues for any bugs found
4. **Performance Tuning**: Adjust configuration based on load test results
5. **Production Readiness**: Deploy to staging environment
6. **Continuous Monitoring**: Set up ongoing health checks and alerts

---

**Reference Documents**:
- [Test Execution Checklist](checklists/test-execution.md) - Detailed procedures
- [Specification](spec.md) - Success criteria definitions
- [Tasks](tasks.md) - Task status tracking
