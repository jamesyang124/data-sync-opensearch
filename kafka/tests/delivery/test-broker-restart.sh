#!/usr/bin/env bash
# T017: Broker Restart Test - Verify at-least-once delivery under broker restart
# Part of Feature 003: Kafka Performance Validation
# Success Criteria SC-003: 0% message loss under broker restart

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
TEST_TOPIC="${TEST_TOPIC:-delivery.broker-restart}"
NUM_RECORDS="${NUM_RECORDS:-1000}"
RECORD_SIZE="${RECORD_SIZE:-256}"

echo "========================================="
echo "Broker Restart Delivery Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Test Topic: $TEST_TOPIC"
echo "Total Records: $NUM_RECORDS"
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
  --config min.insync.replicas=1 \
  || echo "Topic already exists"

# Start background producer (will be interrupted by restart)
echo "[2/6] Starting producer (will send $NUM_RECORDS messages)..."
PRODUCER_OUTPUT="$RESULTS_DIR/broker-restart-producer-$(date +%s).log"

docker compose exec -T kafka kafka-producer-perf-test \
  --topic "$TEST_TOPIC" \
  --num-records "$NUM_RECORDS" \
  --record-size "$RECORD_SIZE" \
  --throughput 100 \
  --producer-props \
    bootstrap.servers="$BOOTSTRAP_SERVER" \
    acks=all \
    retries=2147483647 \
    max.in.flight.requests.per.connection=5 \
  > "$PRODUCER_OUTPUT" 2>&1 &

PRODUCER_PID=$!
echo "  Producer started (PID: $PRODUCER_PID)"
sleep 3

# Restart broker mid-stream
echo "[3/6] Restarting Kafka broker mid-stream..."
echo "  Waiting for producer to send ~30% of messages..."
sleep 3

echo "  Restarting broker NOW..."
docker compose restart kafka >/dev/null 2>&1 &

# Wait for broker to come back up
echo "  Waiting for broker to recover..."
MAX_WAIT=60
WAIT_COUNT=0

while ! docker compose exec -T kafka kafka-broker-api-versions \
       --bootstrap-server "$BOOTSTRAP_SERVER" >/dev/null 2>&1; do
  sleep 1
  WAIT_COUNT=$((WAIT_COUNT + 1))
  if [[ $WAIT_COUNT -ge $MAX_WAIT ]]; then
    echo "  ❌ Broker failed to restart within ${MAX_WAIT}s"
    exit 1
  fi
done

echo "  ✓ Broker recovered in ${WAIT_COUNT}s"

# Wait for producer to finish
echo "[4/6] Waiting for producer to finish..."
wait $PRODUCER_PID 2>/dev/null || true
echo "  Producer finished"

# Count messages in topic
echo "[5/6] Counting messages in topic..."
CONSUMER_OUTPUT="$RESULTS_DIR/broker-restart-consumer-$(date +%s).log"

ACTUAL_COUNT=$(docker compose exec -T kafka kafka-console-consumer \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --topic "$TEST_TOPIC" \
  --from-beginning \
  --timeout-ms 10000 \
  --max-messages "$NUM_RECORDS" \
  2>/dev/null | wc -l || echo "0")

echo "  Messages consumed: $ACTUAL_COUNT"

# Extract producer metrics
SENT_COUNT=$(grep "records sent" "$PRODUCER_OUTPUT" | awk '{print $1}' || echo "0")
if [[ "$SENT_COUNT" == "0" ]]; then
  SENT_COUNT="$NUM_RECORDS"  # Assume all sent if log parsing fails
fi

echo "[6/6] Analyzing results..."
echo ""

# Generate summary
echo "========================================="
echo "BROKER RESTART TEST RESULTS"
echo "========================================="
echo "Messages Sent: $SENT_COUNT"
echo "Messages Received: $ACTUAL_COUNT"
echo "Message Loss: $((SENT_COUNT - ACTUAL_COUNT))"
echo "========================================="

# Validate against SC-003: 0% message loss
if [[ "$ACTUAL_COUNT" -ge "$SENT_COUNT" ]]; then
  echo "✅ PASS: At-least-once delivery guaranteed (received ≥ sent)"
  echo "  - 0% message loss under broker restart"
  exit 0
else
  LOSS_COUNT=$((SENT_COUNT - ACTUAL_COUNT))
  LOSS_PERCENT=$(echo "scale=2; ($LOSS_COUNT * 100) / $SENT_COUNT" | bc)
  echo "❌ FAIL: Message loss detected"
  echo "  - Lost $LOSS_COUNT messages (${LOSS_PERCENT}%)"
  exit 1
fi
