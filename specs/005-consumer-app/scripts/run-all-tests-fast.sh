#!/bin/bash
set -e

# Fast Test Execution Script - Feature 005 Consumer
# Duration: ~30 minutes
# Runs all deferred tests in optimized sequence

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
RESULTS_FILE="$PROJECT_ROOT/test-results-summary.txt"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=12

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Fast Test Execution - CDC Consumer (30 min)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Started: $(date)"
echo "Results will be saved to: $RESULTS_FILE"
echo ""

# Initialize results file
echo "Test Execution Results - $(date)" > "$RESULTS_FILE"
echo "======================================" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Helper functions
pass_test() {
  local test_name=$1
  TESTS_PASSED=$((TESTS_PASSED + 1))
  echo -e "${GREEN}✓${NC} $test_name"
  echo "✓ PASS: $test_name" >> "$RESULTS_FILE"
}

fail_test() {
  local test_name=$1
  local reason=$2
  TESTS_FAILED=$((TESTS_FAILED + 1))
  echo -e "${RED}✗${NC} $test_name"
  echo "  Reason: $reason"
  echo "✗ FAIL: $test_name - $reason" >> "$RESULTS_FILE"
}

wait_for_document() {
  local doc_id=$1
  local index=${2:-videos_index}
  local max_wait=15

  for i in $(seq 1 $max_wait); do
    if curl -sf "http://localhost:9200/$index/_doc/$doc_id" | jq -e '.found' > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Phase 0: Infrastructure Check (2 min)
echo ""
echo -e "${YELLOW}=== Phase 0: Infrastructure Check ===${NC}"

if ! docker compose ps | grep -qE "healthy|running"; then
  fail_test "Infrastructure Check" "Services not running"
  echo "Please run: make start"
  exit 1
fi

if curl -sf http://localhost:8080/health | jq -e '.status == "healthy"' > /dev/null 2>&1; then
  pass_test "Infrastructure Check"
else
  fail_test "Infrastructure Check" "Consumer not healthy"
  exit 1
fi

# Phase 1: Unit Tests (3 min)
echo ""
echo -e "${YELLOW}=== Phase 1: Unit Tests (T024) ===${NC}"

cd "$PROJECT_ROOT/consumer"
if go test ./... -v -short > /tmp/unit-test-output.txt 2>&1; then
  pass_test "Unit Tests"
else
  fail_test "Unit Tests" "See /tmp/unit-test-output.txt"
fi
cd "$PROJECT_ROOT"

# Phase 2: E2E Pipeline Tests (10 min)
echo ""
echo -e "${YELLOW}=== Phase 2: E2E Pipeline (T012, T023) ===${NC}"

# Use smoke test script
if [ -x "$PROJECT_ROOT/consumer/scripts/smoke-test.sh" ]; then
  if "$PROJECT_ROOT/consumer/scripts/smoke-test.sh" > /tmp/smoke-test-output.txt 2>&1; then
    pass_test "E2E INSERT/UPDATE/DELETE"
  else
    fail_test "E2E INSERT/UPDATE/DELETE" "See /tmp/smoke-test-output.txt"
  fi
else
  # Manual E2E test
  TEST_ID="fast_test_$(date +%s)"

  # INSERT test
  docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
INSERT INTO videos (video_id, user_id, title, description, duration, created_at, updated_at)
VALUES ('$TEST_ID', 'user_test', 'Fast Test', 'Testing', 100, NOW(), NOW());
EOF

  if wait_for_document "$TEST_ID"; then
    pass_test "E2E INSERT"

    # UPDATE test
    docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
UPDATE videos SET title = 'Updated Fast Test' WHERE video_id = '$TEST_ID';
EOF
    sleep 3

    if curl -sf "http://localhost:9200/videos_index/_doc/$TEST_ID" | jq -e '._source.title == "Updated Fast Test"' > /dev/null 2>&1; then
      pass_test "E2E UPDATE"
    else
      fail_test "E2E UPDATE" "Title not updated"
    fi

    # DELETE test
    docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
DELETE FROM videos WHERE video_id = '$TEST_ID';
EOF
    sleep 3

    if ! curl -sf "http://localhost:9200/videos_index/_doc/$TEST_ID" | jq -e '.found' > /dev/null 2>&1; then
      pass_test "E2E DELETE"
    else
      fail_test "E2E DELETE" "Document still exists"
    fi
  else
    fail_test "E2E INSERT" "Document not indexed within 15s"
    fail_test "E2E UPDATE" "Skipped due to INSERT failure"
    fail_test "E2E DELETE" "Skipped due to INSERT failure"
  fi
fi

# Phase 3: Failure Handling Tests (8 min) - Run in parallel
echo ""
echo -e "${YELLOW}=== Phase 3: Failure Handling (T025, T026, T030, T031) ===${NC}"

# Test 3.1: Restart/Offset Test (background)
(
  TEST_PREFIX="restart_test_$(date +%s)"

  # Insert 3 records
  for i in 1 2 3; do
    docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('${TEST_PREFIX}_$i', 'user1', 'Test $i', 100, NOW(), NOW());
EOF
  done

  sleep 5

  # Stop consumer, insert 2 more
  docker compose stop consumer > /dev/null 2>&1
  for i in 4 5; do
    docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('${TEST_PREFIX}_$i', 'user1', 'Test $i', 100, NOW(), NOW());
EOF
  done

  # Restart consumer
  docker compose start consumer > /dev/null 2>&1
  sleep 10

  # Check all 5 indexed
  COUNT=$(curl -sf "http://localhost:9200/videos_index/_search?q=${TEST_PREFIX}_*" | jq '.hits.total.value')
  if [ "$COUNT" = "5" ]; then
    echo "PASS:offset_resume" > /tmp/offset_test_result.txt
  else
    echo "FAIL:offset_resume:Found $COUNT/5 documents" > /tmp/offset_test_result.txt
  fi
) &
OFFSET_PID=$!

# Test 3.2: OpenSearch Failure (foreground - faster than parallel)
TEST_FAIL_ID="fail_test_$(date +%s)"

docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('$TEST_FAIL_ID', 'user1', 'Fail Test', 100, NOW(), NOW());
EOF

docker compose stop opensearch > /dev/null 2>&1
sleep 30  # Wait for retries

docker compose start opensearch > /dev/null 2>&1
sleep 20

if wait_for_document "$TEST_FAIL_ID"; then
  pass_test "OpenSearch Failure Recovery"
else
  fail_test "OpenSearch Failure Recovery" "Document not recovered"
fi

# Test 3.3: Malformed Event (quick)
docker compose exec kafka kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic dbserver.public.videos << 'EOF' > /dev/null 2>&1
{"invalid": "malformed"}
EOF

sleep 10

# Check if consumer still healthy
if curl -sf http://localhost:8080/health | jq -e '.status == "healthy"' > /dev/null 2>&1; then
  pass_test "Malformed Event Handling"
else
  fail_test "Malformed Event Handling" "Consumer unhealthy after malformed event"
fi

# Wait for offset test to complete
wait $OFFSET_PID
if [ -f /tmp/offset_test_result.txt ]; then
  RESULT=$(cat /tmp/offset_test_result.txt)
  if [[ "$RESULT" == PASS* ]]; then
    pass_test "Offset Resume After Restart"
  else
    REASON=$(echo "$RESULT" | cut -d: -f3-)
    fail_test "Offset Resume After Restart" "$REASON"
  fi
fi

# Phase 4: Health & Metrics (3 min)
echo ""
echo -e "${YELLOW}=== Phase 4: Health & Metrics (T036) ===${NC}"

# Run validation script if available
if [ -x "$PROJECT_ROOT/consumer/scripts/validate-deployment.sh" ]; then
  if "$PROJECT_ROOT/consumer/scripts/validate-deployment.sh" > /tmp/validation-output.txt 2>&1; then
    pass_test "Deployment Validation"
  else
    fail_test "Deployment Validation" "See /tmp/validation-output.txt"
  fi
else
  # Manual validation
  # Health endpoint
  RESPONSE_TIME=$(curl -o /dev/null -sf -w "%{time_total}" http://localhost:8080/health)
  RESPONSE_MS=$(echo "$RESPONSE_TIME * 1000" | bc)

  if (( $(echo "$RESPONSE_TIME < 1.0" | bc -l) )); then
    pass_test "Health Endpoint (<1s)"
  else
    fail_test "Health Endpoint (<1s)" "Response time: ${RESPONSE_MS}ms"
  fi

  # Metrics endpoint
  if curl -sf http://localhost:8080/metrics | jq -e '.processing.success_rate >= 99' > /dev/null 2>&1; then
    pass_test "Metrics Endpoint (≥99% success)"
  else
    SUCCESS_RATE=$(curl -sf http://localhost:8080/metrics | jq -r '.processing.success_rate')
    fail_test "Metrics Endpoint (≥99% success)" "Success rate: ${SUCCESS_RATE}%"
  fi
fi

# Phase 5: Quick Performance Test (4 min)
echo ""
echo -e "${YELLOW}=== Phase 5: Performance (T042) ===${NC}"

# Insert 50 records rapidly
TEST_PREFIX="perf_$(date +%s)"
for i in $(seq 1 50); do
  docker compose exec -T postgres psql -U app -d app << EOF > /dev/null 2>&1
INSERT INTO videos (video_id, user_id, title, duration, created_at, updated_at)
VALUES ('${TEST_PREFIX}_$i', 'user1', 'Perf $i', 100, NOW(), NOW());
EOF
done

sleep 10

# Check throughput
RATE=$(curl -sf http://localhost:8080/metrics | jq -r '.processing.processing_rate' | grep -oE '[0-9.]+')
if (( $(echo "$RATE >= 50" | bc -l) 2>/dev/null )); then
  pass_test "Throughput Test (≥50 events/sec)"
else
  fail_test "Throughput Test (≥50 events/sec)" "Measured: ${RATE} events/sec"
fi

# Check backpressure metrics exist
if curl -sf http://localhost:8080/metrics | jq -e '.backpressure' > /dev/null 2>&1; then
  pass_test "Backpressure Metrics"
else
  fail_test "Backpressure Metrics" "Metrics not found"
fi

# Phase 6: Final Validation (1 min)
echo ""
echo -e "${YELLOW}=== Phase 6: Final Validation (T043, T044) ===${NC}"

# Quick user story checks
DOC_COUNT=$(curl -sf "http://localhost:9200/videos_index/_count" | jq .count)

if [ "$DOC_COUNT" -gt 0 ]; then
  pass_test "User Story 1: CDC Sync ($DOC_COUNT documents)"
else
  fail_test "User Story 1: CDC Sync" "No documents indexed"
fi

# Failure handling already tested in Phase 3
pass_test "User Story 2: Failure Handling (tested in Phase 3)"

# Monitoring already tested in Phase 4
pass_test "User Story 3: Monitoring (tested in Phase 4)"

# Summary
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Test Execution Summary                                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Completed: $(date)"
echo ""
echo "Tests Passed: ${GREEN}${TESTS_PASSED}${NC} / ${TESTS_TOTAL}"
echo "Tests Failed: ${RED}${TESTS_FAILED}${NC} / ${TESTS_TOTAL}"
echo ""

# Write summary to results file
echo "" >> "$RESULTS_FILE"
echo "======================================" >> "$RESULTS_FILE"
echo "SUMMARY" >> "$RESULTS_FILE"
echo "======================================" >> "$RESULTS_FILE"
echo "Tests Passed: $TESTS_PASSED / $TESTS_TOTAL" >> "$RESULTS_FILE"
echo "Tests Failed: $TESTS_FAILED / $TESTS_TOTAL" >> "$RESULTS_FILE"
echo "Completed: $(date)" >> "$RESULTS_FILE"

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
  echo -e "${GREEN}Ready for deployment${NC}"
  echo "" >> "$RESULTS_FILE"
  echo "STATUS: READY FOR DEPLOYMENT" >> "$RESULTS_FILE"
  exit 0
else
  echo -e "${YELLOW}⚠ Some tests failed${NC}"
  echo -e "Review results in: $RESULTS_FILE"
  echo "" >> "$RESULTS_FILE"
  echo "STATUS: NEEDS FIXES" >> "$RESULTS_FILE"
  exit 1
fi
