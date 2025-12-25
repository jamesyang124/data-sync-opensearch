#!/bin/bash
set -euo pipefail

trap 'echo "✗ test-producer failed at line $LINENO" >&2' ERR

# Produce test messages with at-least-once semantics

TOPIC="${TOPIC:-test.delivery}"
COUNT="${COUNT:-100}"

echo "=== Kafka Test Producer ==="
echo "Topic: $TOPIC"
echo "Count: $COUNT"
echo ""

docker compose exec -T kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --create \
  --if-not-exists \
  --replication-factor 1 \
  --partitions 1 \
  --topic "$TOPIC" >/dev/null

seq 1 "$COUNT" | docker compose exec -T kafka kafka-console-producer \
  --bootstrap-server kafka:9092 \
  --producer-property acks=all \
  --producer-property retries=5 \
  --topic "$TOPIC" >/dev/null

echo "✓ Produced $COUNT messages"
