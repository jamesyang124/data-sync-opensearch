#!/bin/bash
set -euo pipefail

trap 'echo "✗ check-topics failed at line $LINENO" >&2' ERR

echo "=== Kafka Topics ==="
echo ""

docker compose exec -T kafka kafka-topics --bootstrap-server kafka:9092 --list
echo ""
echo "=== Topic Details ==="
docker compose exec -T kafka kafka-topics --bootstrap-server kafka:9092 --describe
