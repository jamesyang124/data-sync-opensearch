#!/bin/bash
# Purpose: Return most viewed videos with recency tie-breaker.
# Usage: ./opensearch/queries/popularity-sort.sh
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ popularity-sort failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search" -H "Content-Type: application/json" -d @- <<EOF
{
  "query": { "match_all": {} },
  "sort": [
    { "view_count": { "order": "desc" } },
    { "published_at": { "order": "desc" } }
  ]
}
EOF
