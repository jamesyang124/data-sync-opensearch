#!/bin/bash
set -euo pipefail

trap 'echo "✗ test-delivery-guarantees failed at line $LINENO" >&2' ERR

# Validate at-least-once delivery under broker restart

TOPIC="${TOPIC:-test.delivery}"
COUNT="${COUNT:-100}"

echo "=== Kafka Delivery Guarantee Test ==="
echo "Topic: $TOPIC"
echo "Count: $COUNT"
echo ""

TOPIC="$TOPIC" COUNT="$COUNT" bash kafka/tests/test-producer.sh

echo "Restarting Kafka broker..."
docker compose restart kafka >/dev/null
sleep 5

RECEIVED=$(TOPIC="$TOPIC" COUNT="$COUNT" bash kafka/tests/test-consumer.sh | tail -n1)

if [ "$RECEIVED" -lt "$COUNT" ]; then
  echo "✗ Expected at least $COUNT messages, got $RECEIVED"
  exit 1
fi

echo "✓ Delivery guarantee validated (received $RECEIVED)"
