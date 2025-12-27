#!/bin/bash
# Purpose: Insert a test document and confirm it is searchable.
# Usage: ./opensearch/tests/test-document-insertion.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ test-document-insertion failed at line $LINENO" >&2' ERR

OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== OpenSearch Document Insertion Test ==="
echo ""

curl -s -X PUT "$OPENSEARCH_URL/videos_index/_doc/video_test" \
  -H "Content-Type: application/json" \
  -d '{"video_id":"video_test","title":"Test Video","view_count":1,"published_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}' >/dev/null

curl -s -X PUT "$OPENSEARCH_URL/users_index/_doc/user_test" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user_test","channel_name":"Test User","subscriber_count":0,"created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}' >/dev/null

curl -s -X PUT "$OPENSEARCH_URL/comments_index/_doc/comment_test" \
  -H "Content-Type: application/json" \
  -d '{"comment_id":"comment_test","video_id":"video_test","user_id":"user_test","comment_text":"ok","posted_at":"2024-01-01T00:00:00Z","created_at":"2024-01-01T00:00:00Z","updated_at":"2024-01-01T00:00:00Z"}' >/dev/null

hits=$(curl -s "$OPENSEARCH_URL/comments_index/_search?q=comment_id:comment_test" | jq -r '.hits.total.value')
if [ "${hits:-0}" -lt 1 ]; then
  echo "✗ Failed to find inserted comment document"
  exit 1
fi

echo "✓ Documents inserted and searchable"

curl -s -X DELETE "$OPENSEARCH_URL/videos_index/_doc/video_test" >/dev/null || true
curl -s -X DELETE "$OPENSEARCH_URL/users_index/_doc/user_test" >/dev/null || true
curl -s -X DELETE "$OPENSEARCH_URL/comments_index/_doc/comment_test" >/dev/null || true
