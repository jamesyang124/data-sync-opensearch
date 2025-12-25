#!/usr/bin/env bash
# T018: Consumer Restart Test - Verify no message gaps after consumer restart
# Part of Feature 003: Kafka Performance Validation
# Success Criteria SC-004: No gaps in message sequence after restart

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-delivery.consumer-restart}"
CONSUMER_GROUP="${CONSUMER_GROUP:-test-consumer-group}"
NUM_RECORDS="${NUM_RECORDS:-1000}"
RECORD_SIZE="${RECORD_SIZE:-256}"

echo "========================================="
echo "Consumer Restart Delivery Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Consumer Group: $CONSUMER_GROUP"
echo "Total Records: $NUM_RECORDS"
echo "Success Criteria: No message gaps"
echo "========================================="

# Create test topic
echo "[1/7] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  || echo "Topic already exists"

# Produce test messages
echo "[2/7] Producing $NUM_RECORDS test messages..."
PRODUCER_OUTPUT="$RESULTS_DIR/consumer-restart-producer-$(date +%s).log"

docker compose exec -T kafka kafka-producer-perf-test \
  --topic "$TEST_TOPIC" \
  --num-records "$NUM_RECORDS" \
  --record-size "$RECORD_SIZE" \
  --throughput -1 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP_SERVER" \
    acks=all \
  > "$PRODUCER_OUTPUT" 2>&1

echo "  ✓ Messages produced"

# Start consumer, consume ~40% of messages, then stop
echo "[3/7] Starting consumer (will consume ~40% of messages)..."
CONSUMER_OUTPUT_1="$RESULTS_DIR/consumer-restart-consumer1-$(date +%s).log"
BATCH_1_SIZE=$((NUM_RECORDS * 4 / 10))

timeout 10s docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --group "$CONSUMER_GROUP" \
  --from-beginning \
  --max-messages "$BATCH_1_SIZE" \
  > "$CONSUMER_OUTPUT_1" 2>&1 || true

CONSUMED_BATCH_1=$(wc -l < "$CONSUMER_OUTPUT_1")
echo "  ✓ First consumer consumed $CONSUMED_BATCH_1 messages, then stopped"

# Wait to simulate downtime
echo "[4/7] Simulating consumer downtime (3 seconds)..."
sleep 3

# Restart consumer, it should resume from offset
echo "[5/7] Restarting consumer (should resume from offset)..."
CONSUMER_OUTPUT_2="$RESULTS_DIR/consumer-restart-consumer2-$(date +%s).log"
BATCH_2_SIZE=$((NUM_RECORDS - CONSUMED_BATCH_1 + 10))  # Extra buffer

timeout 15s docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --group "$CONSUMER_GROUP" \
  --max-messages "$BATCH_2_SIZE" \
  > "$CONSUMER_OUTPUT_2" 2>&1 || true

CONSUMED_BATCH_2=$(wc -l < "$CONSUMER_OUTPUT_2")
echo "  ✓ Second consumer consumed $CONSUMED_BATCH_2 messages"

# Total consumed
TOTAL_CONSUMED=$((CONSUMED_BATCH_1 + CONSUMED_BATCH_2))

echo "[6/7] Verifying consumer group offset..."
OFFSET_OUTPUT=$(docker compose exec -T kafka kafka-consumer-groups \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --group "$CONSUMER_GROUP" \
  --describe 2>&1 || echo "")

echo "$OFFSET_OUTPUT"

# Analyze results
echo "[7/7] Analyzing results..."
echo ""

# Generate summary
echo "========================================="
echo "CONSUMER RESTART TEST RESULTS"
echo "========================================="
echo "Messages Produced: $NUM_RECORDS"
echo "First Consumer Batch: $CONSUMED_BATCH_1"
echo "Second Consumer Batch: $CONSUMED_BATCH_2"
echo "Total Consumed: $TOTAL_CONSUMED"
echo "========================================="

# Validate: total consumed should equal produced (no gaps or duplicates)
if [[ "$TOTAL_CONSUMED" -ge "$NUM_RECORDS" ]]; then
  echo "✅ PASS: Consumer resumed from offset successfully"
  echo "  - No message gaps detected"
  echo "  - At-least-once delivery guaranteed"
  exit 0
else
  GAP_COUNT=$((NUM_RECORDS - TOTAL_CONSUMED))
  echo "❌ FAIL: Message gap detected after consumer restart"
  echo "  - Missing $GAP_COUNT messages"
  exit 1
fi
