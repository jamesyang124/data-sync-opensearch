#!/bin/bash
set -euo pipefail

trap 'echo "✗ create-topics failed at line $LINENO" >&2' ERR

# Create CDC topics in Kafka

TOPICS=(
  "dbserver.public.videos"
  "dbserver.public.users"
  "dbserver.public.comments"
)

echo "=== Creating Kafka CDC Topics ==="
echo ""

for topic in "${TOPICS[@]}"; do
  echo "Creating topic: $topic"
  docker compose exec -T kafka kafka-topics \
    --bootstrap-server kafka:9092 \
    --create \
    --if-not-exists \
    --replication-factor 1 \
    --partitions 1 \
    --topic "$topic"
done

echo ""
echo "✓ Topics created (or already exist)"
