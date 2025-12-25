#!/usr/bin/env bash
# T009: Kafka Sustained Load Test - Test stability at 500 msg/sec for 5 minutes
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-performance.sustained}"
NUM_RECORDS="${NUM_RECORDS:-150000}"
THROUGHPUT="${THROUGHPUT:-500}"
RECORD_SIZE="${RECORD_SIZE:-512}"

echo "========================================="
echo "Kafka Sustained Load Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Sustained Throughput: $THROUGHPUT msg/sec"
echo "Total Records: $NUM_RECORDS"
echo "Record Size: $RECORD_SIZE bytes"
echo "Duration: 300 seconds (5 minutes)"
echo "========================================="

# Create test topic
echo "[1/4] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=3600000 \
  || echo "Topic already exists"

# Run sustained load producer test
echo "[2/4] Running sustained load test (5 minutes at $THROUGHPUT msg/sec)..."
SUSTAINED_OUTPUT="$RESULTS_DIR/sustained-producer-$(date +%s).log"

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
  | tee "$SUSTAINED_OUTPUT"
END_TIME=$(date +%s)

# Extract metrics
echo "[3/4] Parsing sustained load metrics..."
ACTUAL_THROUGHPUT=$(grep "records/sec" "$SUSTAINED_OUTPUT" | awk '{print $2}' | sed 's/[()]//g')
AVG_LATENCY=$(grep "ms avg latency" "$SUSTAINED_OUTPUT" | grep -oP '\d+\.\d+ ms avg latency' | awk '{print $1}')
P95_LATENCY=$(grep "95th" "$SUSTAINED_OUTPUT" | grep -oP '\d+\.\d+ ms 95th' | awk '{print $1}')
DURATION=$((END_TIME - START_TIME))

# Capture resource usage during test
echo "[4/4] Capturing Docker container resource stats..."
STATS_OUTPUT="$RESULTS_DIR/sustained-docker-stats-$(date +%s).log"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" \
  data-sync-opensearch-kafka-1 \
  > "$STATS_OUTPUT" || echo "Could not capture stats"

# Generate summary
echo ""
echo "========================================="
echo "SUSTAINED LOAD TEST RESULTS"
echo "========================================="
echo "Target Throughput: $THROUGHPUT msg/sec"
echo "Actual Throughput: $ACTUAL_THROUGHPUT msg/sec"
echo "Latency (avg): $AVG_LATENCY ms"
echo "Latency (p95): $P95_LATENCY ms"
echo "Test Duration: ${DURATION}s"
echo "========================================="

# Validate: throughput should remain stable, latency should not degrade
THROUGHPUT_STABLE=$(echo "$ACTUAL_THROUGHPUT >= $THROUGHPUT * 0.9" | bc)
LATENCY_STABLE=$(echo "$P95_LATENCY < 200" | bc)

if [[ "$THROUGHPUT_STABLE" == "1" && "$LATENCY_STABLE" == "1" ]]; then
  echo "✅ PASS: Sustained load stable over 5 minutes"
  exit 0
else
  echo "❌ FAIL: Performance degraded over time"
  [[ "$THROUGHPUT_STABLE" != "1" ]] && echo "  - Throughput dropped: $ACTUAL_THROUGHPUT < ${THROUGHPUT} msg/sec"
  [[ "$LATENCY_STABLE" != "1" ]] && echo "  - Latency degraded: $P95_LATENCY >= 200ms"
  exit 1
fi
