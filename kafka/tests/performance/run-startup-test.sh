#!/usr/bin/env bash
# T011: Kafka Startup Test - Measure broker cold start and warm restart time
# Part of Feature 003: Kafka Performance Validation
# Success Criteria SC-002: Broker starts in <10 seconds

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
MAX_STARTUP_SECONDS=10
MAX_WAIT_SECONDS=60

echo "========================================="
echo "Kafka Startup Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "Success Criteria: Start in <${MAX_STARTUP_SECONDS}s"
echo "========================================="

# Function to wait for Kafka to be ready
wait_for_kafka() {
  local start_time=$1
  local wait_limit=$2

  while true; do
    if docker compose exec -T kafka kafka-broker-api-versions \
         --bootstrap-server "$BOOTSTRAP_SERVER" >/dev/null 2>&1; then
      local end_time=$(date +%s)
      local duration=$((end_time - start_time))
      echo "$duration"
      return 0
    fi

    local current_time=$(date +%s)
    if [[ $((current_time - start_time)) -ge $wait_limit ]]; then
      echo "-1"
      return 1
    fi

    sleep 1
  done
}

# Test 1: Warm Restart (broker already running)
echo "[1/2] Testing warm restart..."
echo "  - Restarting Kafka broker..."
START_TIME=$(date +%s)
docker compose restart kafka >/dev/null 2>&1

WARM_STARTUP_TIME=$(wait_for_kafka "$START_TIME" "$MAX_WAIT_SECONDS")

if [[ "$WARM_STARTUP_TIME" == "-1" ]]; then
  echo "  ❌ Kafka failed to start within ${MAX_WAIT_SECONDS}s"
  exit 1
fi

echo "  ✓ Kafka ready in ${WARM_STARTUP_TIME}s"

# Test 2: Cold Start (stop and start broker)
echo "[2/2] Testing cold start..."
echo "  - Stopping Kafka broker..."
docker compose stop kafka >/dev/null 2>&1
sleep 2

echo "  - Starting Kafka broker from stopped state..."
START_TIME=$(date +%s)
docker compose start kafka >/dev/null 2>&1

COLD_STARTUP_TIME=$(wait_for_kafka "$START_TIME" "$MAX_WAIT_SECONDS")

if [[ "$COLD_STARTUP_TIME" == "-1" ]]; then
  echo "  ❌ Kafka failed to start within ${MAX_WAIT_SECONDS}s"
  exit 1
fi

echo "  ✓ Kafka ready in ${COLD_STARTUP_TIME}s"

# Save results
STARTUP_OUTPUT="$RESULTS_DIR/startup-test-$(date +%s).log"
cat > "$STARTUP_OUTPUT" <<EOF
Kafka Startup Test Results
===========================
Warm Restart: ${WARM_STARTUP_TIME}s
Cold Start: ${COLD_STARTUP_TIME}s
Threshold: <${MAX_STARTUP_SECONDS}s

EOF

# Generate summary
echo ""
echo "========================================="
echo "STARTUP TEST RESULTS"
echo "========================================="
echo "Warm Restart: ${WARM_STARTUP_TIME}s"
echo "Cold Start: ${COLD_STARTUP_TIME}s"
echo "Threshold: <${MAX_STARTUP_SECONDS}s"
echo "========================================="

# Validate against SC-002: Broker starts in <10 seconds
if [[ "$COLD_STARTUP_TIME" -lt "$MAX_STARTUP_SECONDS" && "$WARM_STARTUP_TIME" -lt "$MAX_STARTUP_SECONDS" ]]; then
  echo "✅ PASS: Both startup tests meet SC-002 (<${MAX_STARTUP_SECONDS}s)"
  echo "Result: PASS" >> "$STARTUP_OUTPUT"
  exit 0
else
  echo "❌ FAIL: Startup time exceeds threshold"
  [[ "$COLD_STARTUP_TIME" -ge "$MAX_STARTUP_SECONDS" ]] && echo "  - Cold start: ${COLD_STARTUP_TIME}s >= ${MAX_STARTUP_SECONDS}s"
  [[ "$WARM_STARTUP_TIME" -ge "$MAX_STARTUP_SECONDS" ]] && echo "  - Warm restart: ${WARM_STARTUP_TIME}s >= ${MAX_STARTUP_SECONDS}s"
  echo "Result: FAIL" >> "$STARTUP_OUTPUT"
  exit 1
fi
