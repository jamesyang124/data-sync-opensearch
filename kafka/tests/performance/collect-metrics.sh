#!/usr/bin/env bash
# T012: Metrics Collection - Parse kafka-perf-test output and capture Docker stats
# Part of Feature 003: Kafka Performance Validation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

# Usage: collect-metrics.sh <test_name> <log_file>
TEST_NAME="${1:-unknown}"
LOG_FILE="${2:-}"

if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
  echo "Usage: $0 <test_name> <log_file>"
  echo "Example: $0 throughput /path/to/throughput-producer-1234567890.log"
  exit 1
fi

echo "========================================="
echo "Metrics Collection: $TEST_NAME"
echo "========================================="
echo "Log File: $LOG_FILE"
echo ""

# Extract producer metrics
echo "[1/3] Extracting producer metrics..."
PRODUCER_THROUGHPUT=$(grep "records/sec" "$LOG_FILE" | awk '{print $2}' | sed 's/[()]//g' || echo "N/A")
AVG_LATENCY=$(grep "ms avg latency" "$LOG_FILE" | grep -oP '\d+\.\d+ ms avg latency' | awk '{print $1}' || echo "N/A")
P50_LATENCY=$(grep "50th" "$LOG_FILE" | grep -oP '\d+\.\d+ ms 50th' | awk '{print $1}' || echo "N/A")
P95_LATENCY=$(grep "95th" "$LOG_FILE" | grep -oP '\d+\.\d+ ms 95th' | awk '{print $1}' || echo "N/A")
P99_LATENCY=$(grep "99th" "$LOG_FILE" | grep -oP '\d+\.\d+ ms 99th' | awk '{print $1}' || echo "N/A")
MAX_LATENCY=$(grep "max latency" "$LOG_FILE" | grep -oP '\d+\.\d+ ms max latency' | awk '{print $1}' || echo "N/A")

# Extract throughput in MB/sec if available
MB_PER_SEC=$(grep "MB/sec" "$LOG_FILE" | awk '{print $5}' | head -n 1 || echo "N/A")

echo "  Throughput: $PRODUCER_THROUGHPUT msg/sec ($MB_PER_SEC MB/sec)"
echo "  Latency (avg): $AVG_LATENCY ms"
echo "  Latency (p50): $P50_LATENCY ms"
echo "  Latency (p95): $P95_LATENCY ms"
echo "  Latency (p99): $P99_LATENCY ms"
echo "  Latency (max): $MAX_LATENCY ms"

# Capture Docker stats
echo ""
echo "[2/3] Capturing Docker container resource usage..."
STATS_OUTPUT="$RESULTS_DIR/${TEST_NAME}-docker-stats-$(date +%s).log"

docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
  data-sync-opensearch-kafka-1 \
  data-sync-opensearch-connect-1 \
  > "$STATS_OUTPUT" 2>/dev/null || echo "  Warning: Could not capture stats"

if [[ -f "$STATS_OUTPUT" ]]; then
  echo "  Saved to: $STATS_OUTPUT"
  cat "$STATS_OUTPUT"
fi

# Generate JSON metrics for programmatic analysis
echo ""
echo "[3/3] Generating JSON metrics..."
METRICS_JSON="$RESULTS_DIR/${TEST_NAME}-metrics-$(date +%s).json"

cat > "$METRICS_JSON" <<EOF
{
  "test_name": "$TEST_NAME",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "producer": {
    "throughput_msg_per_sec": "$PRODUCER_THROUGHPUT",
    "throughput_mb_per_sec": "$MB_PER_SEC",
    "latency": {
      "avg_ms": "$AVG_LATENCY",
      "p50_ms": "$P50_LATENCY",
      "p95_ms": "$P95_LATENCY",
      "p99_ms": "$P99_LATENCY",
      "max_ms": "$MAX_LATENCY"
    }
  },
  "log_file": "$LOG_FILE",
  "stats_file": "$STATS_OUTPUT"
}
EOF

echo "  Saved to: $METRICS_JSON"

# Display summary
echo ""
echo "========================================="
echo "Metrics Collection Complete"
echo "========================================="
echo "Test: $TEST_NAME"
echo "Throughput: $PRODUCER_THROUGHPUT msg/sec"
echo "P95 Latency: $P95_LATENCY ms"
echo "JSON: $METRICS_JSON"
echo "Stats: $STATS_OUTPUT"
echo "========================================="

exit 0
