#!/bin/bash
# Purpose: Profile a sample query and display timing breakdown.
# Usage: ./opensearch/scripts/check-query-performance.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ check-query-performance failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== OpenSearch Query Performance ==="
echo ""

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search?profile=true" \
  -H "Content-Type: application/json" \
  -d '{"query":{"match_all":{}},"size":1}' | jq '.profile'
