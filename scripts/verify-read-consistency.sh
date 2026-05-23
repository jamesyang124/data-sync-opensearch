#!/usr/bin/env bash
# Purpose: Verify producer CUD operations eventually become consistent in OpenSearch.
# Usage: scripts/verify-read-consistency.sh
# Env: PRODUCER_URL, OPENSEARCH_URL, VERIFY_TIMEOUT_SECONDS
# Deps: curl, jq
set -euo pipefail

PRODUCER_URL="${PRODUCER_URL:-http://localhost:8082}"
OPENSEARCH_URL="${OPENSEARCH_URL:-http://localhost:9200}"
TIMEOUT_SECONDS="${VERIFY_TIMEOUT_SECONDS:-90}"
RUN_ID="${RUN_ID:-verify-$(date +%s)-$RANDOM}"
TMP_DIR="$(mktemp -d)"
STOP_FILE="$TMP_DIR/stop"
READ_LOG="$TMP_DIR/concurrent-reads.log"

cleanup() {
  touch "$STOP_FILE" 2>/dev/null || true
  if [[ -n "${READER_PID:-}" ]]; then
    wait "$READER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "missing required command: $1" >&2
    exit 127
  fi
}

request_json() {
  local method="$1"
  local path="$2"
  local body="$3"
  local expected="$4"
  local response_file="$TMP_DIR/response.json"
  local status

  status="$(curl -sS -o "$response_file" -w "%{http_code}" \
    -X "$method" "$PRODUCER_URL$path" \
    -H "Content-Type: application/json" \
    -d "$body")"

  if [[ "$status" != "$expected" ]]; then
    echo "unexpected producer response for $method $path: got $status, expected $expected" >&2
    cat "$response_file" >&2
    exit 1
  fi
}

request_delete() {
  local path="$1"
  local expected="$2"
  local response_file="$TMP_DIR/delete-response.txt"
  local status

  status="$(curl -sS -o "$response_file" -w "%{http_code}" -X DELETE "$PRODUCER_URL$path")"
  if [[ "$status" != "$expected" ]]; then
    echo "unexpected producer response for DELETE $path: got $status, expected $expected" >&2
    cat "$response_file" >&2
    exit 1
  fi
}

doc_status() {
  local index="$1"
  local id="$2"
  local body_file="$3"
  curl -sS -o "$body_file" -w "%{http_code}" "$OPENSEARCH_URL/$index/_doc/$id"
}

wait_field() {
  local index="$1"
  local id="$2"
  local field="$3"
  local expected="$4"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  local body_file="$TMP_DIR/$index-$id.json"
  local status actual

  while (( SECONDS < deadline )); do
    status="$(doc_status "$index" "$id" "$body_file")"
    if [[ "$status" == "200" ]]; then
      actual="$(jq -r --arg field "$field" '._source[$field] // empty | tostring' "$body_file")"
      if [[ "$actual" == "$expected" ]]; then
        return 0
      fi
    fi
    sleep 1
  done

  echo "timed out waiting for $index/$id field $field to equal $expected" >&2
  if [[ -f "$body_file" ]]; then
    cat "$body_file" >&2
  fi
  exit 1
}

wait_deleted() {
  local index="$1"
  local id="$2"
  local deadline=$((SECONDS + TIMEOUT_SECONDS))
  local body_file="$TMP_DIR/$index-$id-delete.json"
  local status

  while (( SECONDS < deadline )); do
    status="$(doc_status "$index" "$id" "$body_file")"
    if [[ "$status" == "404" ]]; then
      return 0
    fi
    sleep 1
  done

  echo "timed out waiting for $index/$id to be deleted" >&2
  if [[ -f "$body_file" ]]; then
    cat "$body_file" >&2
  fi
  exit 1
}

concurrent_reader() {
  local ids=("$@")
  while [[ ! -f "$STOP_FILE" ]]; do
    for pair in "${ids[@]}"; do
      local index="${pair%%:*}"
      local id="${pair#*:}"
      local status
      status="$(curl -sS -o /dev/null -w "%{http_code}" "$OPENSEARCH_URL/$index/_doc/$id" || true)"
      printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pair" "$status" >>"$READ_LOG"
    done
    sleep 0.05
  done
}

require_cmd curl
require_cmd jq

curl -fsS "$PRODUCER_URL/health" >/dev/null
curl -fsS "$OPENSEARCH_URL" >/dev/null

USER_ID="channel_${RUN_ID}_main"
VIDEO_ID="video_${RUN_ID}_main"
COMMENT_ID="comment_${RUN_ID}_main"
DELETE_USER_ID="channel_${RUN_ID}_delete"
DELETE_VIDEO_ID="video_${RUN_ID}_delete"
DELETE_COMMENT_ID="comment_${RUN_ID}_delete"

MAIN_USER_NAME="Verify ${RUN_ID} User"
MAIN_USER_UPDATED="Verify ${RUN_ID} User Updated"
MAIN_VIDEO_TITLE="Verify ${RUN_ID} Video"
MAIN_VIDEO_UPDATED="Verify ${RUN_ID} Video Updated"
MAIN_COMMENT_TEXT="Verify ${RUN_ID} comment"
MAIN_COMMENT_UPDATED="Verify ${RUN_ID} comment updated"

touch "$READ_LOG"
concurrent_reader \
  "users_index:$USER_ID" \
  "videos_index:$VIDEO_ID" \
  "comments_index:$COMMENT_ID" \
  "users_index:$DELETE_USER_ID" \
  "videos_index:$DELETE_VIDEO_ID" \
  "comments_index:$DELETE_COMMENT_ID" &
READER_PID=$!

request_json POST /api/v1/users/ "$(jq -cn --arg id "$USER_ID" --arg name "$MAIN_USER_NAME" '{channel_id:$id, channel_name:$name}')" 201
request_json POST /api/v1/videos/ "$(jq -cn --arg id "$VIDEO_ID" --arg title "$MAIN_VIDEO_TITLE" '{video_id:$id, title:$title, category:"verification"}')" 201
request_json POST /api/v1/comments/ "$(jq -cn --arg id "$COMMENT_ID" --arg video "$VIDEO_ID" --arg channel "$USER_ID" --arg text "$MAIN_COMMENT_TEXT" '{comment_id:$id, video_id:$video, channel_id:$channel, comment_text:$text, likes:1, replies:0, sentiment_label:"neutral", country_code:"US"}')" 201

request_json POST /api/v1/users/ "$(jq -cn --arg id "$DELETE_USER_ID" '{channel_id:$id, channel_name:"delete candidate"}')" 201
request_json POST /api/v1/videos/ "$(jq -cn --arg id "$DELETE_VIDEO_ID" '{video_id:$id, title:"delete candidate", category:"verification"}')" 201
request_json POST /api/v1/comments/ "$(jq -cn --arg id "$DELETE_COMMENT_ID" --arg video "$VIDEO_ID" --arg channel "$USER_ID" '{comment_id:$id, video_id:$video, channel_id:$channel, comment_text:"delete candidate", likes:0, replies:0, sentiment_label:"neutral", country_code:"US"}')" 201

request_json PUT "/api/v1/users/$USER_ID" "$(jq -cn --arg name "$MAIN_USER_UPDATED" '{channel_name:$name}')" 200
request_json PUT "/api/v1/videos/$VIDEO_ID" "$(jq -cn --arg title "$MAIN_VIDEO_UPDATED" '{title:$title, category:"verification-updated"}')" 200
request_json PUT "/api/v1/comments/$COMMENT_ID" "$(jq -cn --arg video "$VIDEO_ID" --arg channel "$USER_ID" --arg text "$MAIN_COMMENT_UPDATED" '{video_id:$video, channel_id:$channel, comment_text:$text, likes:2, replies:1, sentiment_label:"positive", country_code:"US"}')" 200

request_delete "/api/v1/comments/$DELETE_COMMENT_ID" 204
request_delete "/api/v1/videos/$DELETE_VIDEO_ID" 204
request_delete "/api/v1/users/$DELETE_USER_ID" 204

wait_field users_index "$USER_ID" channel_name "$MAIN_USER_UPDATED"
wait_field videos_index "$VIDEO_ID" title "$MAIN_VIDEO_UPDATED"
wait_field comments_index "$COMMENT_ID" comment_text "$MAIN_COMMENT_UPDATED"
wait_field comments_index "$COMMENT_ID" likes "2"
wait_deleted comments_index "$DELETE_COMMENT_ID"
wait_deleted videos_index "$DELETE_VIDEO_ID"
wait_deleted users_index "$DELETE_USER_ID"

touch "$STOP_FILE"
wait "$READER_PID" 2>/dev/null || true

READ_COUNT="$(wc -l <"$READ_LOG" | tr -d ' ')"
BAD_READ_COUNT="$(awk '$3 !~ /^(200|404)$/ {count++} END {print count + 0}' "$READ_LOG")"
if [[ "$BAD_READ_COUNT" != "0" ]]; then
  echo "concurrent reads returned unexpected OpenSearch statuses" >&2
  awk '$3 !~ /^(200|404)$/ {print}' "$READ_LOG" >&2
  exit 1
fi

jq -n \
  --arg run_id "$RUN_ID" \
  --arg producer_url "$PRODUCER_URL" \
  --arg opensearch_url "$OPENSEARCH_URL" \
  --arg user_id "$USER_ID" \
  --arg video_id "$VIDEO_ID" \
  --arg comment_id "$COMMENT_ID" \
  --argjson concurrent_reads "$READ_COUNT" \
  '{
    result: "pass",
    run_id: $run_id,
    producer_url: $producer_url,
    opensearch_url: $opensearch_url,
    verified: {
      create_update: {
        users_index: $user_id,
        videos_index: $video_id,
        comments_index: $comment_id
      },
      deletes: ["comments_index", "videos_index", "users_index"],
      concurrent_opensearch_reads: $concurrent_reads
    }
  }'
