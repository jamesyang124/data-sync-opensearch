#!/bin/bash
# Purpose: Run filtered search with category aggregation and view stats.
# Usage: ./opensearch/queries/filtered-aggregations.sh [search_term] [category]
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ filtered-aggregations failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
TERM="${1:-tutorial}"
CATEGORY="${2:-Education}"

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search" -H "Content-Type: application/json" -d @- <<EOF
{
  "query": {
    "bool": {
      "must": { "match": { "title": "$TERM" } },
      "filter": [
        { "term": { "category": "$CATEGORY" } }
      ]
    }
  },
  "aggs": {
    "category_breakdown": { "terms": { "field": "category", "size": 10 } },
    "view_count_stats": { "stats": { "field": "view_count" } },
    "published_over_time": { "date_histogram": { "field": "published_at", "calendar_interval": "month" } }
  },
  "size": 10,
  "_source": ["video_id", "title", "category", "view_count"]
}
EOF
