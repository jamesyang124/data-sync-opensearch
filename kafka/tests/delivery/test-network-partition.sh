#!/usr/bin/env bash
# T019: Network Partition Test - Verify no loss when Kafka container paused 10s
# Part of Feature 003: Kafka Performance Validation
# Success Criteria: Messages buffered during partition, delivered after recovery

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-delivery.network-partition}"
NUM_RECORDS="${NUM_RECORDS:-500}"
RECORD_SIZE="${RECORD_SIZE:-256}"
PARTITION_DURATION=10

echo "========================================="
echo "Network Partition Delivery Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Total Records: $NUM_RECORDS"
echo "Partition Duration: ${PARTITION_DURATION}s"
echo "Success Criteria: 0% message loss"
echo "========================================="

# Create test topic
echo "[1/6] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  || echo "Topic already exists"

# Start background producer
echo "[2/6] Starting producer (will send $NUM_RECORDS messages at 50 msg/sec)..."
PRODUCER_OUTPUT="$RESULTS_DIR/network-partition-producer-$(date +%s).log"

docker compose exec -T kafka kafka-producer-perf-test \
  --topic "$TEST_TOPIC" \
  --num-records "$NUM_RECORDS" \
  --record-size "$RECORD_SIZE" \
  --throughput 50 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP_SERVER" \
    acks=all \
    retries=2147483647 \
    request.timeout.ms=30000 \
    retry.backoff.ms=1000 \
  > "$PRODUCER_OUTPUT" 2>&1 &

PRODUCER_PID=$!
echo "  Producer started (PID: $PRODUCER_PID)"
sleep 2

# Simulate network partition by pausing Kafka container
echo "[3/6] Simulating network partition (pausing Kafka container for ${PARTITION_DURATION}s)..."
echo "  Pausing Kafka NOW..."
docker compose pause kafka

sleep "$PARTITION_DURATION"

echo "  Resuming Kafka after ${PARTITION_DURATION}s..."
docker compose unpause kafka

echo "  ✓ Kafka resumed"

# Wait for broker to stabilize
echo "[4/6] Waiting for broker to stabilize..."
sleep 5

MAX_WAIT=60
WAIT_COUNT=0

while ! docker compose exec -T kafka kafka-broker-api-versions \
       --bootstrap-server "$BOOTSTRAP_SERVER" >/dev/null 2>&1; do
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
  if [[ $WAIT_COUNT -ge $MAX_WAIT ]]; then
    echo "  ❌ Broker failed to recover within ${MAX_WAIT}s"
    exit 1
  fi
done

echo "  ✓ Broker recovered in ${WAIT_COUNT}s"

# Wait for producer to finish
echo "  Waiting for producer to finish..."
wait $PRODUCER_PID 2>/dev/null || true
echo "  ✓ Producer finished"

# Count messages in topic
echo "[5/6] Counting messages in topic..."
CONSUMER_OUTPUT="$RESULTS_DIR/network-partition-consumer-$(date +%s).log"

sleep 2

ACTUAL_COUNT=$(docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --from-beginning \
  --timeout-ms 10000 \
  --max-messages "$NUM_RECORDS" \
  2>/dev/null | wc -l || echo "0")

echo "  Messages consumed: $ACTUAL_COUNT"

# Extract producer metrics
SENT_COUNT=$(grep "records sent" "$PRODUCER_OUTPUT" | awk '{print $1}' || echo "$NUM_RECORDS")

echo "[6/6] Analyzing results..."
echo ""

# Generate summary
echo "========================================="
echo "NETWORK PARTITION TEST RESULTS"
echo "========================================="
echo "Messages Sent: $SENT_COUNT"
echo "Messages Received: $ACTUAL_COUNT"
echo "Partition Duration: ${PARTITION_DURATION}s"
echo "Message Loss: $((SENT_COUNT - ACTUAL_COUNT))"
echo "========================================="

# Validate: no message loss despite network partition
if [[ "$ACTUAL_COUNT" -ge "$SENT_COUNT" ]]; then
  echo "✅ PASS: Messages delivered after network partition recovery"
  echo "  - Producer buffered messages during partition"
  echo "  - 0% message loss"
  exit 0
else
  LOSS_COUNT=$((SENT_COUNT - ACTUAL_COUNT))
  LOSS_PERCENT=$(echo "scale=2; ($LOSS_COUNT * 100) / $SENT_COUNT" | bc)
  echo "❌ FAIL: Message loss during network partition"
  echo "  - Lost $LOSS_COUNT messages (${LOSS_PERCENT}%)"
  exit 1
fi
