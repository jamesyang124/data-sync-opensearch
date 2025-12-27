#!/bin/bash
# Purpose: Return newest videos by published_at.
# Usage: ./opensearch/queries/recency-sort.sh
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ recency-sort failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search" -H "Content-Type: application/json" -d @- <<EOF
{
  "query": { "match_all": {} },
  "sort": [{ "published_at": { "order": "desc" } }]
}
EOF
