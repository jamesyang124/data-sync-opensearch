#!/usr/bin/env bash
# T022: Run All Delivery Tests - Execute all 5 delivery guarantee tests in sequence
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELIVERY_DIR="$SCRIPT_DIR/delivery"
RESULTS_DIR="$SCRIPT_DIR/results"

echo "========================================="
echo "Kafka Delivery Guarantee Test Suite"
echo "========================================="
echo "Running all 5 delivery guarantee tests..."
echo "========================================="
echo ""

# Track test results
TOTAL_TESTS=5
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TEST_NAMES=()

# Test 1: Broker Restart (0% message loss under broker restart)
echo "[1/5] Running Broker Restart Test..."
if bash "$DELIVERY_DIR/test-broker-restart.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Broker Restart Test")
fi
echo ""

# Test 2: Consumer Restart (no message gaps after consumer restart)
echo "[2/5] Running Consumer Restart Test..."
if bash "$DELIVERY_DIR/test-consumer-restart.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Consumer Restart Test")
fi
echo ""

# Test 3: Network Partition (no loss during 10s partition)
echo "[3/5] Running Network Partition Test..."
if bash "$DELIVERY_DIR/test-network-partition.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Network Partition Test")
fi
echo ""

# Test 4: Debezium Offset Recovery (CDC resumes from offset)
echo "[4/5] Running Debezium Offset Recovery Test..."
if bash "$DELIVERY_DIR/test-debezium-offset-recovery.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Debezium Offset Recovery Test")
fi
echo ""

# Test 5: Multiple Consumers (independent consumption)
echo "[5/5] Running Multiple Consumers Test..."
if bash "$DELIVERY_DIR/test-multiple-consumers.sh"; then
  echo "  ✅ PASSED"
  PASSED_TESTS=$((PASSED_TESTS + 1))
else
  echo "  ❌ FAILED"
  FAILED_TESTS=$((FAILED_TESTS + 1))
  FAILED_TEST_NAMES+=("Multiple Consumers Test")
fi
echo ""

# Generate summary
SUMMARY_FILE="$RESULTS_DIR/delivery-summary-$(date +%s).log"
cat > "$SUMMARY_FILE" <<EOF
Kafka Delivery Guarantee Test Suite Summary
============================================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Total Tests: $TOTAL_TESTS
Passed: $PASSED_TESTS
Failed: $FAILED_TESTS

Test Results:
-------------
1. Broker Restart Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Broker Restart Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
2. Consumer Restart Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Consumer Restart Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
3. Network Partition Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Network Partition Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
4. Debezium Offset Recovery Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Debezium Offset Recovery Test " ]]; then echo "PASS"; else echo "FAIL"; fi)
5. Multiple Consumers Test: $(if [[ ! " ${FAILED_TEST_NAMES[@]} " =~ " Multiple Consumers Test " ]]; then echo "PASS"; else echo "FAIL"; fi)

EOF

if [[ $FAILED_TESTS -gt 0 ]]; then
  echo "Failed Tests:" >> "$SUMMARY_FILE"
  for test_name in "${FAILED_TEST_NAMES[@]}"; do
    echo "  - $test_name" >> "$SUMMARY_FILE"
  done
fi

# Display final summary
echo "========================================="
echo "DELIVERY GUARANTEE TEST SUITE RESULTS"
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
  echo "❌ Delivery test suite FAILED ($FAILED_TESTS/$TOTAL_TESTS tests failed)"
  exit 1
else
  echo "✅ Delivery test suite PASSED (all $TOTAL_TESTS tests passed)"
  exit 0
fi
