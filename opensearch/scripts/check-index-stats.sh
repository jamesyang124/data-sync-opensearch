#!/bin/bash
# Purpose: Show index sizes and document counts.
# Usage: ./opensearch/scripts/check-index-stats.sh
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ check-index-stats failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== OpenSearch Index Stats ==="
echo ""

curl -s "$OPENSEARCH_URL/_cat/indices?v"
