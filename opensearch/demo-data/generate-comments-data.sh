#!/bin/bash
# Purpose: Generate JSONL bulk data for comments_index.
# Usage: COUNT=8500 OUT=opensearch/demo-data/comments.jsonl ./opensearch/demo-data/generate-comments-data.sh
# Env: COUNT, OUT
# Deps: bash
set -euo pipefail

trap 'echo "✗ generate-comments-data failed at line $LINENO" >&2' ERR

COUNT="${COUNT:-8500}"
OUT="${OUT:-opensearch/demo-data/comments.jsonl}"
TEN_MIN_AGO_SEC=$(date -v-10M +%s)
BASE_TS_MS="${BASE_TS_MS:-${TEN_MIN_AGO_SEC}000}"
INTERVAL=70

echo "Generating $COUNT comment documents -> $OUT"
mkdir -p "$(dirname "$OUT")"

for i in $(seq 1 "$COUNT"); do
  ts_ms=$((BASE_TS_MS + i * INTERVAL))
  cat <<EOF
{ "index": { "_index": "comments_index", "_id": "comment_$i" } }
{ "comment_id": "comment_$i", "video_id": "video_$((i%1000+1))", "user_id": "user_$((i%500+1))", "comment_text": "Comment $i", "sentiment": "neutral", "like_count": $((i%50)), "posted_at": $ts_ms, "created_at": $ts_ms, "updated_at": $ts_ms, "parent_comment_id": null }
EOF
done > "$OUT"
