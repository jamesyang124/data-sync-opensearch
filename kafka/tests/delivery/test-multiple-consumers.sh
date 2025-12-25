#!/usr/bin/env bash
# T021: Multiple Consumers Test - Verify 2 consumer groups receive all messages
# Part of Feature 003: Kafka Performance Validation
# Success Criteria: Both consumer groups receive 100% of messages independently

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-delivery.multiple-consumers}"
CONSUMER_GROUP_1="${CONSUMER_GROUP_1:-test-group-1}"
CONSUMER_GROUP_2="${CONSUMER_GROUP_2:-test-group-2}"
NUM_RECORDS="${NUM_RECORDS:-500}"
RECORD_SIZE="${RECORD_SIZE:-256}"

echo "========================================="
echo "Multiple Consumers Delivery Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Consumer Group 1: $CONSUMER_GROUP_1"
echo "Consumer Group 2: $CONSUMER_GROUP_2"
echo "Total Records: $NUM_RECORDS"
echo "Success Criteria: Both groups receive all messages"
echo "========================================="

# Create test topic
echo "[1/5] Creating test topic..."
docker compose exec -T kafka kafka-topics \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create --if-not-exists \
  --topic "$TEST_TOPIC" \
  --partitions 3 \
  --replication-factor 1 \
  || echo "Topic already exists"

# Produce test messages
echo "[2/5] Producing $NUM_RECORDS test messages..."
PRODUCER_OUTPUT="$RESULTS_DIR/multiple-consumers-producer-$(date +%s).log"

docker compose exec -T kafka kafka-producer-perf-test \
  --topic "$TEST_TOPIC" \
  --num-records "$NUM_RECORDS" \
  --record-size "$RECORD_SIZE" \
  --throughput -1 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP_SERVER" \
    acks=all \
  > "$PRODUCER_OUTPUT" 2>&1

SENT_COUNT=$(grep "records sent" "$PRODUCER_OUTPUT" | awk '{print $1}' || echo "$NUM_RECORDS")
echo "  ✓ Messages produced: $SENT_COUNT"

# Consumer Group 1
echo "[3/5] Starting Consumer Group 1..."
CONSUMER_OUTPUT_1="$RESULTS_DIR/multiple-consumers-group1-$(date +%s).log"

docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --group "$CONSUMER_GROUP_1" \
  --from-beginning \
  --timeout-ms 10000 \
  --max-messages "$NUM_RECORDS" \
  > "$CONSUMER_OUTPUT_1" 2>&1 || true

CONSUMED_GROUP_1=$(wc -l < "$CONSUMER_OUTPUT_1")
echo "  ✓ Group 1 consumed: $CONSUMED_GROUP_1 messages"

# Consumer Group 2
echo "[4/5] Starting Consumer Group 2 (independent from Group 1)..."
CONSUMER_OUTPUT_2="$RESULTS_DIR/multiple-consumers-group2-$(date +%s).log"

docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --group "$CONSUMER_GROUP_2" \
  --from-beginning \
  --timeout-ms 10000 \
  --max-messages "$NUM_RECORDS" \
  > "$CONSUMER_OUTPUT_2" 2>&1 || true

CONSUMED_GROUP_2=$(wc -l < "$CONSUMER_OUTPUT_2")
echo "  ✓ Group 2 consumed: $CONSUMED_GROUP_2 messages"

# Verify consumer group offsets
echo "[5/5] Verifying consumer group offsets..."
echo ""
echo "Consumer Group 1 Offsets:"
docker compose exec -T kafka kafka-consumer-groups \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --group "$CONSUMER_GROUP_1" \
  --describe 2>&1 | grep "$TEST_TOPIC" || echo "  No offset data"

echo ""
echo "Consumer Group 2 Offsets:"
docker compose exec -T kafka kafka-consumer-groups \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --group "$CONSUMER_GROUP_2" \
  --describe 2>&1 | grep "$TEST_TOPIC" || echo "  No offset data"

# Analyze results
echo ""
echo "========================================="
echo "MULTIPLE CONSUMERS TEST RESULTS"
echo "========================================="
echo "Messages Produced: $SENT_COUNT"
echo "Group 1 Consumed: $CONSUMED_GROUP_1"
echo "Group 2 Consumed: $CONSUMED_GROUP_2"
echo "========================================="

# Validate: both groups should receive all messages
GROUP_1_OK=$([[ "$CONSUMED_GROUP_1" -ge "$SENT_COUNT" ]] && echo "1" || echo "0")
GROUP_2_OK=$([[ "$CONSUMED_GROUP_2" -ge "$SENT_COUNT" ]] && echo "1" || echo "0")

if [[ "$GROUP_1_OK" == "1" && "$GROUP_2_OK" == "1" ]]; then
  echo "✅ PASS: Both consumer groups received all messages"
  echo "  - Group 1: $CONSUMED_GROUP_1/$SENT_COUNT messages"
  echo "  - Group 2: $CONSUMED_GROUP_2/$SENT_COUNT messages"
  echo "  - Independent consumption verified"
  exit 0
else
  echo "❌ FAIL: Not all consumer groups received full message set"
  [[ "$GROUP_1_OK" != "1" ]] && echo "  - Group 1 missing: $((SENT_COUNT - CONSUMED_GROUP_1)) messages"
  [[ "$GROUP_2_OK" != "1" ]] && echo "  - Group 2 missing: $((SENT_COUNT - CONSUMED_GROUP_2)) messages"
  exit 1
fi
