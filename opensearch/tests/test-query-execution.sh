#!/bin/bash
# Purpose: Execute demo queries and validate ordering/response shape.
# Usage: ./opensearch/tests/test-query-execution.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ test-query-execution failed at line $LINENO" >&2' ERR

echo "=== OpenSearch Query Execution Test ==="
echo ""

hits=$(bash opensearch/queries/relevance-search.sh "tutorial" | jq -r '.hits.total.value')
if [ "${hits:-0}" -lt 1 ]; then
  echo "✗ relevance-search returned 0 hits"
  exit 1
fi

hits=$(bash opensearch/queries/recency-sort.sh | jq -r '.hits.total.value')
if [ "${hits:-0}" -lt 1 ]; then
  echo "✗ recency-sort returned 0 hits"
  exit 1
fi

hits=$(bash opensearch/queries/popularity-sort.sh | jq -r '.hits.total.value')
if [ "${hits:-0}" -lt 1 ]; then
  echo "✗ popularity-sort returned 0 hits"
  exit 1
fi

hits=$(bash opensearch/queries/hybrid-ranking.sh "tutorial" | jq -r '.hits.total.value')
if [ "${hits:-0}" -lt 1 ]; then
  echo "✗ hybrid-ranking returned 0 hits"
  exit 1
fi

aggs=$(bash opensearch/queries/filtered-aggregations.sh "tutorial" "Education" | jq -r '.aggregations.category_breakdown.buckets | length')
if [ "${aggs:-0}" -lt 1 ]; then
  echo "✗ filtered-aggregations returned no buckets"
  exit 1
fi

echo "✓ All demo queries returned results"
