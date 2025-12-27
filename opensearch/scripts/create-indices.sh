#!/bin/bash
# Purpose: Create OpenSearch indices using local mapping files.
# Usage: ./opensearch/scripts/create-indices.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ create-indices failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== Creating OpenSearch Indices ==="
echo ""

curl -s -X PUT "$OPENSEARCH_URL/videos_index" \
  -H "Content-Type: application/json" \
  -d @opensearch/mappings/videos-index.json | jq '.'

curl -s -X PUT "$OPENSEARCH_URL/users_index" \
  -H "Content-Type: application/json" \
  -d @opensearch/mappings/users-index.json | jq '.'

curl -s -X PUT "$OPENSEARCH_URL/comments_index" \
  -H "Content-Type: application/json" \
  -d @opensearch/mappings/comments-index.json | jq '.'

echo ""
echo "✓ Indices created"
