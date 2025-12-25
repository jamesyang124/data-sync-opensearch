#!/usr/bin/env bash
# T008: Kafka Burst Test - Test backpressure handling at 5000 msg/sec for 10s
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-performance.burst}"
NUM_RECORDS="${NUM_RECORDS:-50000}"
THROUGHPUT="${THROUGHPUT:-5000}"
RECORD_SIZE="${RECORD_SIZE:-512}"

echo "========================================="
echo "Kafka Burst Test (Backpressure)"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Burst Throughput: $THROUGHPUT msg/sec"
echo "Total Records: $NUM_RECORDS"
echo "Record Size: $RECORD_SIZE bytes"
echo "Duration: 10 seconds"
echo "========================================="

# Create test topic
echo "[1/3] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=3600000 \
  || echo "Topic already exists"

# Run burst producer test
echo "[2/3] Running burst producer test (10s at $THROUGHPUT msg/sec)..."
BURST_OUTPUT="$RESULTS_DIR/burst-producer-$(date +%s).log"

START_TIME=$(date +%s)
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
    linger.ms=1 \
    batch.size=16384 \
  | tee "$BURST_OUTPUT"
END_TIME=$(date +%s)

# Extract metrics
echo "[3/3] Parsing burst test metrics..."
ACTUAL_THROUGHPUT=$(grep "records/sec" "$BURST_OUTPUT" | awk '{print $2}' | sed 's/[()]//g')
AVG_LATENCY=$(grep "ms avg latency" "$BURST_OUTPUT" | grep -oP '\d+\.\d+ ms avg latency' | awk '{print $1}')
MAX_LATENCY=$(grep "max latency" "$BURST_OUTPUT" | grep -oP '\d+\.\d+ ms max latency' | awk '{print $1}')
DURATION=$((END_TIME - START_TIME))

# Generate summary
echo ""
echo "========================================="
echo "BURST TEST RESULTS"
echo "========================================="
echo "Target Throughput: $THROUGHPUT msg/sec"
echo "Actual Throughput: $ACTUAL_THROUGHPUT msg/sec"
echo "Latency (avg): $AVG_LATENCY ms"
echo "Latency (max): $MAX_LATENCY ms"
echo "Test Duration: ${DURATION}s"
echo "========================================="

# Validate: producer should handle burst without errors
THROUGHPUT_RATIO=$(echo "scale=2; $ACTUAL_THROUGHPUT / $THROUGHPUT" | bc)
echo "Throughput Ratio: $THROUGHPUT_RATIO (actual/target)"

if [[ $(echo "$THROUGHPUT_RATIO >= 0.8" | bc) == "1" ]]; then
  echo "✅ PASS: Backpressure handled successfully (${THROUGHPUT_RATIO}x target)"
  exit 0
else
  echo "❌ FAIL: Throughput degraded significantly (${THROUGHPUT_RATIO}x target)"
  exit 1
fi
