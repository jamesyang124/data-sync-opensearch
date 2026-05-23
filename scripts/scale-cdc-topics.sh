#!/usr/bin/env bash
# Purpose: Create or increase CDC topic partitions for local consumer scaling.
# Usage: CDC_TOPIC_PARTITIONS=6 scripts/scale-cdc-topics.sh
# Env: COMPOSE, CDC_TOPIC_PARTITIONS
# Deps: docker compose
set -euo pipefail

COMPOSE="${COMPOSE:-docker compose}"
TARGET_PARTITIONS="${CDC_TOPIC_PARTITIONS:-6}"
REPLICATION_FACTOR="${CDC_TOPIC_REPLICATION_FACTOR:-1}"
TOPICS=(
  dbserver.public.users
  dbserver.public.videos
  dbserver.public.comments
  dbserver.public.users.dlq
  dbserver.public.videos.dlq
  dbserver.public.comments.dlq
)

if ! [[ "$TARGET_PARTITIONS" =~ ^[0-9]+$ ]] || (( TARGET_PARTITIONS < 1 )); then
  echo "CDC_TOPIC_PARTITIONS must be a positive integer" >&2
  exit 2
fi

kafka_topics() {
  $COMPOSE exec -T kafka kafka-topics --bootstrap-server kafka:9092 "$@"
}

topic_partitions() {
  local topic="$1"
  kafka_topics --describe --topic "$topic" 2>/dev/null |
    awk -F'PartitionCount: ' 'NF > 1 {split($2, fields, "\t"); print fields[1]; exit}'
}

for topic in "${TOPICS[@]}"; do
  current="$(topic_partitions "$topic" || true)"
  if [[ -z "$current" ]]; then
    echo "creating $topic with $TARGET_PARTITIONS partitions"
    kafka_topics --create \
      --if-not-exists \
      --topic "$topic" \
      --partitions "$TARGET_PARTITIONS" \
      --replication-factor "$REPLICATION_FACTOR"
    continue
  fi

  if (( current < TARGET_PARTITIONS )); then
    echo "increasing $topic partitions: $current -> $TARGET_PARTITIONS"
    kafka_topics --alter --topic "$topic" --partitions "$TARGET_PARTITIONS"
  else
    echo "$topic already has $current partitions"
  fi
done

echo ""
kafka_topics --describe | awk '/dbserver\.public\.(users|videos|comments)/ {print}'
