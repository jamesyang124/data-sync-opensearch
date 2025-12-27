#!/bin/bash
# Purpose: Generate JSONL bulk data for users_index.
# Usage: COUNT=500 OUT=opensearch/demo-data/users.jsonl ./opensearch/demo-data/generate-users-data.sh
# Env: COUNT, OUT
# Deps: bash
set -euo pipefail

trap 'echo "✗ generate-users-data failed at line $LINENO" >&2' ERR

COUNT="${COUNT:-500}"
OUT="${OUT:-opensearch/demo-data/users.jsonl}"
TEN_MIN_AGO_SEC=$(date -v-10M +%s)
BASE_TS_MS="${BASE_TS_MS:-${TEN_MIN_AGO_SEC}000}"
INTERVAL=70

echo "Generating $COUNT user documents -> $OUT"
mkdir -p "$(dirname "$OUT")"

for i in $(seq 1 "$COUNT"); do
  ts_ms=$((BASE_TS_MS + i * INTERVAL))
  cat <<EOF
{ "index": { "_index": "users_index", "_id": "user_$i" } }
{ "user_id": "user_$i", "username": "user_$i", "channel_name": "Channel $i", "subscriber_count": $((i*3)), "created_at": $ts_ms, "updated_at": $ts_ms, "verified": false, "description": "User $i" }
EOF
done > "$OUT"
