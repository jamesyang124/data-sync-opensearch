#!/bin/bash
# Purpose: Run demo query scripts and summarize results.
# Usage: ./opensearch/scripts/run-demo-queries.sh
# Env: OPENSEARCH_URL
# Deps: bash, jq
set -euo pipefail

trap 'echo "✗ run-demo-queries failed at line $LINENO" >&2' ERR

echo "=== Running Demo Queries ==="
echo ""

bash opensearch/queries/relevance-search.sh "tutorial" | jq '.hits.total.value'
bash opensearch/queries/recency-sort.sh | jq '.hits.total.value'
bash opensearch/queries/popularity-sort.sh | jq '.hits.total.value'
bash opensearch/queries/hybrid-ranking.sh "tutorial" | jq '.hits.total.value'
bash opensearch/queries/filtered-aggregations.sh "tutorial" "Education" | jq '.aggregations.category_breakdown'
