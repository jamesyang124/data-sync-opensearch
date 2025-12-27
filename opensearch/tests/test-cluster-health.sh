#!/bin/bash
# Purpose: Check cluster health and stats endpoints.
# Usage: ./opensearch/tests/test-cluster-health.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ test-cluster-health failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== OpenSearch Cluster Health Test ==="
echo ""

status=$(curl -s "$OPENSEARCH_URL/_cluster/health" | jq -r '.status')
nodes=$(curl -s "$OPENSEARCH_URL/_cluster/health" | jq -r '.number_of_nodes')

if [ "$status" != "green" ] && [ "$status" != "yellow" ]; then
  echo "✗ Unexpected cluster status: $status"
  exit 1
fi

if [ "$nodes" -lt 1 ]; then
  echo "✗ Expected at least 1 node, got $nodes"
  exit 1
fi

cluster_stats=$(curl -s "$OPENSEARCH_URL/_cluster/stats")
cluster_name=$(echo "$cluster_stats" | jq -r '.cluster_name')
index_count=$(echo "$cluster_stats" | jq -r '.indices.count')
node_count=$(curl -s "$OPENSEARCH_URL/_nodes/stats" | jq -r '.nodes | length')

if [ -z "$cluster_name" ] || [ "$cluster_name" = "null" ]; then
  echo "✗ Missing cluster_name from /_cluster/stats"
  exit 1
fi

if [ "$index_count" = "null" ]; then
  echo "✗ Missing indices count from /_cluster/stats"
  exit 1
fi

if [ "$node_count" -lt 1 ]; then
  echo "✗ Missing node stats from /_nodes/stats"
  exit 1
fi

echo "✓ Cluster health ok (status=$status, nodes=$nodes, indices=$index_count)"
