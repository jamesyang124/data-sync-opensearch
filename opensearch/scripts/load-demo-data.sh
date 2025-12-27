#!/bin/bash
# Purpose: Generate and bulk load demo data into OpenSearch indices.
# Usage: ./opensearch/scripts/load-demo-data.sh
# Env: OPENSEARCH_URL, VIDEO_COUNT, USER_COUNT, COMMENT_COUNT
# Deps: curl
set -euo pipefail

trap 'echo "✗ load-demo-data failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
VIDEO_COUNT="${VIDEO_COUNT:-1000}"
USER_COUNT="${USER_COUNT:-500}"
COMMENT_COUNT="${COMMENT_COUNT:-8500}"

echo "=== Loading OpenSearch Demo Data ==="

bash opensearch/demo-data/generate-videos-data.sh COUNT="$VIDEO_COUNT"
bash opensearch/demo-data/generate-users-data.sh COUNT="$USER_COUNT"
bash opensearch/demo-data/generate-comments-data.sh COUNT="$COMMENT_COUNT"

for file in opensearch/demo-data/videos.jsonl opensearch/demo-data/users.jsonl opensearch/demo-data/comments.jsonl; do
  echo "Loading $file"
  curl -s -H "Content-Type: application/x-ndjson" -X POST "$OPENSEARCH_URL/_bulk" --data-binary "@$file" >/dev/null
done

echo "✓ Demo data loaded"
