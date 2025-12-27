#!/bin/bash
# Purpose: Run all OpenSearch integration tests and report a summary.
# Usage: ./opensearch/tests/test-all.sh
# Env: OPENSEARCH_URL
# Deps: bash
set -u
set -o pipefail

tests=(
  "opensearch/tests/test-index-creation.sh"
  "opensearch/tests/test-document-insertion.sh"
  "opensearch/tests/test-query-execution.sh"
  "opensearch/tests/test-cluster-health.sh"
)

pass_count=0
fail_count=0

echo "=== OpenSearch Integration Tests ==="

for test in "${tests[@]}"; do
  echo ""
  echo "Running ${test}..."
  if bash "$test"; then
    echo "✓ ${test} passed"
    pass_count=$((pass_count + 1))
  else
    echo "✗ ${test} failed"
    fail_count=$((fail_count + 1))
  fi
done

echo ""
echo "Summary: ${pass_count} passed, ${fail_count} failed"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi
