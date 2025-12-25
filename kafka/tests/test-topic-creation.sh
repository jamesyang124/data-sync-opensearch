#!/bin/bash
set -euo pipefail

trap 'echo "✗ test-topic-creation failed at line $LINENO" >&2' ERR

# Create a test topic and verify it exists

echo "=== Kafka Topic Creation Test ==="
echo ""

TOPIC="test.topic.healthcheck"

docker compose exec -T kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --create \
  --if-not-exists \
  --replication-factor 1 \
  --partitions 1 \
  --topic "$TOPIC"

if docker compose exec -T kafka kafka-topics --bootstrap-server kafka:9092 --list | grep -q "$TOPIC"; then
  echo "✓ Topic created and listed"
else
  echo "✗ Topic not found after creation"
  exit 1
fi

docker compose exec -T kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --delete \
  --topic "$TOPIC" >/dev/null || true

echo "✓ Cleanup complete"
