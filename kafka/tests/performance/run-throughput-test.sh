#!/usr/bin/env bash
# T007: Kafka Throughput Test - Validate ≥1000 msg/sec with <100ms p95 latency
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-performance.throughput}"
NUM_RECORDS="${NUM_RECORDS:-60000}"
THROUGHPUT="${THROUGHPUT:-1000}"
RECORD_SIZE="${RECORD_SIZE:-512}"

echo "========================================="
echo "Kafka Throughput Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Target Throughput: $THROUGHPUT msg/sec"
echo "Total Records: $NUM_RECORDS"
echo "Record Size: $RECORD_SIZE bytes"
echo "Duration: 60 seconds"
echo "========================================="

# Create test topic with CDC-like configuration
echo "[1/4] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=3600000 \
  --config compression.type=lz4 \
  || echo "Topic already exists"

# Run producer performance test
echo "[2/4] Running producer performance test (60s at $THROUGHPUT msg/sec)..."
PRODUCER_OUTPUT="$RESULTS_DIR/throughput-producer-$(date +%s).log"

docker compose exec -T kafka kafka-producer-perf-test \
  --topic "$TEST_TOPIC" \
  --num-records "$NUM_RECORDS" \
  --record-size "$RECORD_SIZE" \
  --throughput "$THROUGHPUT" \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP_SERVER" \
    acks=all \
    retries=2147483647 \
    max.in.flight.requests.per.connection=5 \
    compression.type=lz4 \
  | tee "$PRODUCER_OUTPUT"

# Extract metrics
echo "[3/4] Parsing producer metrics..."
PRODUCER_THROUGHPUT=$(grep "records/sec" "$PRODUCER_OUTPUT" | awk '{print $2}' | sed 's/[()]//g')
AVG_LATENCY=$(grep "ms avg latency" "$PRODUCER_OUTPUT" | grep -oP '\d+\.\d+ ms avg latency' | awk '{print $1}')
P95_LATENCY=$(grep "95th" "$PRODUCER_OUTPUT" | grep -oP '\d+\.\d+ ms 95th' | awk '{print $1}')
P99_LATENCY=$(grep "99th" "$PRODUCER_OUTPUT" | grep -oP '\d+\.\d+ ms 99th' | awk '{print $1}')

# Run consumer performance test
echo "[4/4] Running consumer performance test..."
CONSUMER_OUTPUT="$RESULTS_DIR/throughput-consumer-$(date +%s).log"

docker compose exec -T kafka kafka-consumer-perf-test \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --messages "$NUM_RECORDS" \
  --threads 1 \
  --timeout 120000 \
  --show-detailed-stats \
  | tee "$CONSUMER_OUTPUT"

CONSUMER_THROUGHPUT=$(grep "MB/sec" "$CONSUMER_OUTPUT" | tail -n 1 | awk '{print $4}')

# Generate summary
echo ""
echo "========================================="
echo "THROUGHPUT TEST RESULTS"
echo "========================================="
echo "Producer Throughput: $PRODUCER_THROUGHPUT msg/sec"
echo "Producer Latency (avg): $AVG_LATENCY ms"
echo "Producer Latency (p95): $P95_LATENCY ms"
echo "Producer Latency (p99): $P99_LATENCY ms"
echo "Consumer Throughput: $CONSUMER_THROUGHPUT msg/sec"
echo "========================================="

# Validate against SC-001: ≥1000 msg/sec, <100ms p95 latency
THROUGHPUT_OK=$(echo "$PRODUCER_THROUGHPUT >= 1000" | bc -l)
LATENCY_OK=$(echo "$P95_LATENCY < 100" | bc -l)

if [[ "$THROUGHPUT_OK" == "1" && "$LATENCY_OK" == "1" ]]; then
  echo "✅ PASS: Meets SC-001 (≥1000 msg/sec, <100ms p95 latency)"
  exit 0
else
  echo "❌ FAIL: Does not meet SC-001"
  [[ "$THROUGHPUT_OK" != "1" ]] && echo "  - Throughput: $PRODUCER_THROUGHPUT < 1000 msg/sec"
  [[ "$LATENCY_OK" != "1" ]] && echo "  - P95 Latency: $P95_LATENCY >= 100ms"
  exit 1
fi
