#!/bin/bash
# Purpose: Generate JSONL bulk data for videos_index.
# Usage: COUNT=1000 OUT=opensearch/demo-data/videos.jsonl ./opensearch/demo-data/generate-videos-data.sh
# Env: COUNT, OUT
# Deps: bash
set -euo pipefail

trap 'echo "✗ generate-videos-data failed at line $LINENO" >&2' ERR

COUNT="${COUNT:-1000}"
OUT="${OUT:-opensearch/demo-data/videos.jsonl}"
TEN_MIN_AGO_SEC=$(date -v-10M +%s)
BASE_TS_MS="${BASE_TS_MS:-${TEN_MIN_AGO_SEC}000}"
INTERVAL=70

echo "Generating $COUNT video documents -> $OUT"
mkdir -p "$(dirname "$OUT")"

for i in $(seq 1 "$COUNT"); do
  ts_ms=$((BASE_TS_MS + i * INTERVAL))
  cat <<EOF
{ "index": { "_index": "videos_index", "_id": "video_$i" } }
{ "video_id": "video_$i", "title": "Tutorial Video $i", "description": "Tutorial description $i", "channel_id": "channel_$((i%100))", "view_count": $((i*10)), "like_count": $((i*2)), "published_at": $ts_ms, "duration_seconds": 120, "category": "Education", "tags": ["tutorial", "demo"], "created_at": $ts_ms, "updated_at": $ts_ms }
EOF
done > "$OUT"
