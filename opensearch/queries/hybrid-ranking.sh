#!/bin/bash
# Purpose: Combine relevance, recency, and popularity in a function_score query.
# Usage: ./opensearch/queries/hybrid-ranking.sh "search terms"
# Env: OPENSEARCH_URL
# Deps: curl
set -euo pipefail

trap 'echo "✗ hybrid-ranking failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
TERM="${1:-tutorial}"

curl -s -X POST "$OPENSEARCH_URL/videos_index/_search" -H "Content-Type: application/json" -d @- <<EOF
{
  "query": {
    "function_score": {
      "query": {
        "multi_match": {
          "query": "$TERM",
          "fields": ["title^2", "description", "tags"]
        }
      },
      "functions": [
        {
          "gauss": {
            "published_at": {
              "origin": "now",
              "scale": "30d",
              "decay": 0.5
            }
          }
        },
        {
          "field_value_factor": {
            "field": "view_count",
            "factor": 0.001,
            "modifier": "log1p"
          }
        }
      ],
      "score_mode": "sum",
      "boost_mode": "sum"
    }
  }
}
EOF
