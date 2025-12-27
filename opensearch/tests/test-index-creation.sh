#!/bin/bash
# Purpose: Verify indices exist and mappings are applied correctly.
# Usage: ./opensearch/tests/test-index-creation.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ test-index-creation failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== OpenSearch Index Creation Test ==="
echo ""

indices=(videos_index users_index comments_index)

for idx in "${indices[@]}"; do
  if ! curl -s "$OPENSEARCH_URL/_cat/indices/$idx?h=index" | grep -q "$idx"; then
    echo "✗ Missing index: $idx"
    exit 1
  fi
done

echo "✓ All indices exist"

video_type=$(curl -s "$OPENSEARCH_URL/videos_index/_mapping" | jq -r '.[].mappings.properties.title.type')
view_type=$(curl -s "$OPENSEARCH_URL/videos_index/_mapping" | jq -r '.[].mappings.properties.view_count.type')
updated_type=$(curl -s "$OPENSEARCH_URL/videos_index/_mapping" | jq -r '.[].mappings.properties.updated_at.type')

if [ "$video_type" != "text" ] || [ "$view_type" != "long" ] || [ "$updated_type" != "date" ]; then
  echo "✗ videos_index mapping types mismatch"
  exit 1
fi

echo "✓ videos_index mappings verified"
