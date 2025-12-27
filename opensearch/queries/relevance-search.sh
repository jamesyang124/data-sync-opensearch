#!/bin/bash
# Purpose: Run a relevance-ranked search across title/description/tags.
# Usage: ./opensearch/queries/relevance-search.sh "search terms"
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ relevance-search failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
TERM="${1:-tutorial}"

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search" -H "Content-Type: application/json" -d @- <<EOF
{
  "query": {
    "multi_match": {
      "query": "$TERM",
      "fields": ["title^2", "description", "tags"]
    }
  }
}
EOF
