#!/bin/bash
# Purpose: Wait for OpenSearch cluster health to reach green.
# Usage: ./opensearch/scripts/wait-for-health.sh
# Env: OPENSEARCH_URL, MAX_WAIT
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ wait-for-health failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
MAX_WAIT="${MAX_WAIT:-30}"

echo "Waiting for OpenSearch health at $OPENSEARCH_URL..."

for i in $(seq 1 "$MAX_WAIT"); do
  STATUS=$(curl -s "$OPENSEARCH_URL/_cluster/health" | jq -r '.status' 2>/dev/null || echo "unknown")
  if [ "$STATUS" = "green" ]; then
    echo "✓ OpenSearch is green"
    exit 0
  fi
  echo "  Waiting... ($i/$MAX_WAIT) status=$STATUS"
  sleep 2
done

echo "✗ OpenSearch not green after $MAX_WAIT attempts"
exit 1
