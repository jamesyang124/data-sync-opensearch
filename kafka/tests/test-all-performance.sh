#!/usr/bin/env bash
# T014: Run All Performance Tests - Execute all 5 performance benchmarks in sequence
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PERF_DIR="$SCRIPT_DIR/performance"
RESULTS_DIR="$SCRIPT_DIR/results"

echo "========================================="
echo "Kafka Performance Test Suite"
echo "========================================="
echo "Running all 5 performance benchmarks..."
echo "========================================="
echo ""

# Track test results
TOTAL_TESTS=5
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TEST_NAMES=()

# Test 1: Throughput Test (≥1000 msg/sec, <100ms p95 latency)
echo "[1/5] Running Throughput Test..."
if bash "$PERF_DIR/run-throughput-test.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Throughput Test")
fi
echo ""

# Test 2: Burst Test (backpressure handling at 5000 msg/sec)
echo "[2/5] Running Burst Test..."
if bash "$PERF_DIR/run-burst-test.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Burst Test")
fi
echo ""

# Test 3: Sustained Load Test (500 msg/sec for 5 minutes)
echo "[3/5] Running Sustained Load Test..."
if bash "$PERF_DIR/run-sustained-load-test.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Sustained Load Test")
fi
echo ""

# Test 4: Snapshot Simulation (895K records)
echo "[4/5] Running Snapshot Simulation..."
if bash "$PERF_DIR/run-snapshot-simulation.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Snapshot Simulation")
fi
echo ""

# Test 5: Startup Test (broker cold start <10s)
echo "[5/5] Running Startup Test..."
if bash "$PERF_DIR/run-startup-test.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Startup Test")
fi
echo ""

# Generate summary
SUMMARY_FILE="$RESULTS_DIR/performance-summary-$(date +%s).log"
cat > "$SUMMARY_FILE" <<EOF
Kafka Performance Test Suite Summary
=====================================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Total Tests: $TOTAL_TESTS
Passed: $PASSED_TESTS
Failed: $FAILED_TESTS

Test Results:
-------------
1. Throughput Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Throughput Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
2. Burst Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Burst Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
3. Sustained Load Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Sustained Load Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
4. Snapshot Simulation: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Snapshot Simulation " ]]; then echo "PASS"; else echo "FAIL"; fi)
5. Startup Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Startup Test " ]]; then echo "PASS"; else echo "FAIL"; fi)

EOF

if [[ $FAILED_TESTS -gt 0 ]]; then
  echo "Failed Tests:" >> "$SUMMARY_FILE"
  for test_name in "${FAILED_TEST_NAMES[@]}"; do
    echo "  - $test_name" >> "$SUMMARY_FILE"
  done
fi

# Display final summary
echo "========================================="
echo "PERFORMANCE TEST SUITE RESULTS"
echo "========================================="
echo "Total Tests: $TOTAL_TESTS"
echo "Passed: $PASSED_TESTS"
echo "Failed: $FAILED_TESTS"
echo ""
cat "$SUMMARY_FILE"
echo ""
echo "Summary saved to: $SUMMARY_FILE"
echo "========================================="

# Exit with failure if any tests failed
if [[ $FAILED_TESTS -gt 0 ]]; then
  echo "❌ Performance test suite FAILED ($FAILED_TESTS/$TOTAL_TESTS tests failed)"
  exit 1
else
  echo "✅ Performance test suite PASSED (all $TOTAL_TESTS tests passed)"
  exit 0
fi
