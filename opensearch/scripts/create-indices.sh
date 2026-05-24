#!/bin/bash
# Purpose: Create OpenSearch indices using local mapping files. Skips if already exists.
# Usage: ./opensearch/scripts/create-indices.sh
# Env: OPENSEARCH_URL
# Deps: curl, jq
set -euo pipefail

trap 'echo "✗ create-indices failed at line $LINENO" >&2' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"

echo "=== Creating OpenSearch Indices ==="
echo ""

create_index() {
  local name="$1"
  local mapping="$2"

  # Check if index already exists; distinguish 404 (not found) from other errors
  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/$name")
  if [ "$http_code" = "200" ]; then
    echo "✓ $name already exists, skipping"
    return
  elif [ "$http_code" != "404" ]; then
    echo "✗ Existence check for $name returned unexpected HTTP $http_code (OpenSearch may be unavailable)"
    exit 1
  fi

  # Create the index; fail loudly on non-200/201
  local response status body
  response=$(curl -s -w "\n%{http_code}" -X PUT "$OPENSEARCH_URL/$name" \
    -H "Content-Type: application/json" \
    -d "@$mapping")
  status=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  if [ "$status" = "200" ] || [ "$status" = "201" ]; then
    echo "✓ $name created"
  else
    echo "✗ Failed to create $name (HTTP $status)"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    exit 1
  fi
}

create_index "videos_index"   "$REPO_ROOT/opensearch/mappings/videos-index.json"
create_index "users_index"    "$REPO_ROOT/opensearch/mappings/users-index.json"
create_index "comments_index" "$REPO_ROOT/opensearch/mappings/comments-index.json"

echo ""
echo "✓ Indices ready"
