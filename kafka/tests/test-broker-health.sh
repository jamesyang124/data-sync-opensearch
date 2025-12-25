#!/bin/bash
set -euo pipefail

trap 'echo "✗ test-broker-health failed at line $LINENO" >&2' ERR

# Verify Kafka broker is reachable (KRaft mode)

echo "=== Kafka Broker Health Check ==="
echo ""

if ! docker compose ps kafka --status=running | grep -q kafka; then
  echo "✗ Kafka container is not running"
  exit 1
fi

docker compose exec -T kafka kafka-topics \
  --bootstrap-server kafka:9092 \
  --list >/dev/null

echo "✓ Kafka broker is reachable"
