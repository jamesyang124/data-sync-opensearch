#!/bin/bash
set -e

# Run all PostgreSQL integration tests and report summary

echo "========================================="
echo "PostgreSQL Integration Tests - Full Suite"
echo "========================================="
echo ""

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASSED=0
FAILED=0
TOTAL=0

run_test() {
  local test_script=$1
  local test_name=$(basename "$test_script" .sh)

  echo "Running: $test_name"
  echo "---"

  if bash "$test_script"; then
    echo "✅ PASSED: $test_name"
    ((PASSED++))
  else
    echo "❌ FAILED: $test_name"
    ((FAILED++))
  fi

  ((TOTAL++))
  echo ""
}

# Run all test scripts
run_test "$TESTS_DIR/test-database-connectivity.sh"
run_test "$TESTS_DIR/test-schema-validation.sh"
run_test "$TESTS_DIR/test-data-loading.sh"
run_test "$TESTS_DIR/test-makefile-commands.sh"

# Print summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
  echo "✅ All tests passed!"
  exit 0
else
  echo "❌ Some tests failed"
  exit 1
fi
