#!/bin/bash
set -euo pipefail

trap 'echo "✗ test-consumer failed at line $LINENO" >&2' ERR

# Consume a fixed number of messages and report count

TOPIC="${TOPIC:-test.delivery}"
COUNT="${COUNT:-100}"

echo "=== Kafka Test Consumer ==="
echo "Topic: $TOPIC"
echo "Count: $COUNT"
echo ""

RECEIVED=$(docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --from-beginning \
  --max-messages "$COUNT" \
  --topic "$TOPIC" | wc -l | tr -d '[:space:]')

echo "✓ Consumed $RECEIVED messages"
echo "$RECEIVED"
