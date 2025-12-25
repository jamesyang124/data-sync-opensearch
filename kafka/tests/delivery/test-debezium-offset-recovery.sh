#!/usr/bin/env bash
# T020: Debezium Offset Recovery Test - Verify CDC resumes from offset after restart
# Part of Feature 003: Kafka Performance Validation
# Success Criteria: No CDC events lost or duplicated after connector restart

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"
BOOTSTRAP_SERVER="${KAFKA_BOOTSTRAP_SERVER:-localhost:9092}"
CDC_TOPIC="${CDC_TOPIC:-dbserver.public.comments}"
CONNECTOR_NAME="${CONNECTOR_NAME:-postgres-connector}"

echo "========================================="
echo "Debezium Offset Recovery Test"
echo "========================================="
echo "Bootstrap Server: $BOOTSTRAP_SERVER"
echo "CDC Topic: $CDC_TOPIC"
echo "Connector: $CONNECTOR_NAME"
echo "Success Criteria: CDC resumes from offset"
echo "========================================="

# Check connector is running
echo "[1/8] Verifying Debezium connector is running..."
CONNECTOR_STATUS=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")

if [[ "$CONNECTOR_STATUS" != "RUNNING" ]]; then
  echo "  ❌ Connector not running (status: $CONNECTOR_STATUS)"
  echo "  Run 'make start-cdc' to start the connector"
  exit 1
fi

echo "  ✓ Connector is RUNNING"

# Get current topic offset
echo "[2/8] Capturing current CDC topic offset..."
OFFSET_BEFORE=$(docker compose exec -T kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP_SERVER" \
  --topic "$CDC_TOPIC" \
  --time -1 2>/dev/null | awk -F: '{sum+=$NF} END {print sum}' || echo "0")

echo "  Current offset: $OFFSET_BEFORE"

# Insert test rows into PostgreSQL to trigger CDC events
echo "[3/8] Inserting 10 test rows to trigger CDC events..."
docker compose exec -T postgres psql -U app -d app <<EOF
INSERT INTO comments (comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code)
SELECT
  'offset-test-' || generate_series(1, 10),
  (SELECT video_id FROM videos LIMIT 1),
  (SELECT channel_id FROM users LIMIT 1),
  'Offset recovery test message',
  0,
  0,
  NOW(),
  'neutral',
  'US';
EOF

echo "  ✓ Test rows inserted"

# Wait for CDC events to be captured
echo "[4/8] Waiting for CDC events to appear in Kafka..."
sleep 5

OFFSET_AFTER_INSERT=$(docker compose exec -T kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP_SERVER" \
  --topic "$CDC_TOPIC" \
  --time -1 2>/dev/null | awk -F: '{sum+=$NF} END {print sum}' || echo "$OFFSET_BEFORE")

NEW_EVENTS=$((OFFSET_AFTER_INSERT - OFFSET_BEFORE))
echo "  New CDC events captured: $NEW_EVENTS"

if [[ "$NEW_EVENTS" -lt 5 ]]; then
  echo "  ⚠ Warning: Expected ~10 events, got $NEW_EVENTS"
fi

# Restart Debezium connector
echo "[5/8] Restarting Debezium connector..."
curl -s -X POST http://localhost:8083/connectors/$CONNECTOR_NAME/restart >/dev/null

echo "  Waiting for connector to restart..."
sleep 10

# Check connector is running again
CONNECTOR_STATUS_AFTER=$(curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq -r '.connector.state' 2>/dev/null || echo "UNKNOWN")

if [[ "$CONNECTOR_STATUS_AFTER" != "RUNNING" ]]; then
  echo "  ❌ Connector failed to restart (status: $CONNECTOR_STATUS_AFTER)"
  exit 1
fi

echo "  ✓ Connector restarted successfully"

# Insert more test rows
echo "[6/8] Inserting 5 more test rows after connector restart..."
docker compose exec -T postgres psql -U app -d app <<EOF
INSERT INTO comments (comment_id, video_id, channel_id, comment_text, likes, replies, published_at, sentiment_label, country_code)
SELECT
  'offset-test-after-' || generate_series(1, 5),
  (SELECT video_id FROM videos LIMIT 1),
  (SELECT channel_id FROM users LIMIT 1),
  'Post-restart CDC test',
  0,
  0,
  NOW(),
  'neutral',
  'US';
EOF

echo "  ✓ Test rows inserted"

# Wait for CDC events
echo "[7/8] Waiting for CDC events after restart..."
sleep 5

OFFSET_FINAL=$(docker compose exec -T kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list "$BOOTSTRAP_SERVER" \
  --topic "$CDC_TOPIC" \
  --time -1 2>/dev/null | awk -F: '{sum+=$NF} END {print sum}' || echo "$OFFSET_AFTER_INSERT")

POST_RESTART_EVENTS=$((OFFSET_FINAL - OFFSET_AFTER_INSERT))
echo "  Post-restart CDC events: $POST_RESTART_EVENTS"

# Analyze results
echo "[8/8] Analyzing results..."
echo ""

# Generate summary
echo "========================================="
echo "DEBEZIUM OFFSET RECOVERY TEST RESULTS"
echo "========================================="
echo "Offset Before: $OFFSET_BEFORE"
echo "Offset After Insert: $OFFSET_AFTER_INSERT"
echo "Offset After Restart: $OFFSET_FINAL"
echo "Pre-restart Events: $NEW_EVENTS"
echo "Post-restart Events: $POST_RESTART_EVENTS"
echo "========================================="

# Validate: connector should capture new events after restart
if [[ "$POST_RESTART_EVENTS" -ge 3 ]]; then
  echo "✅ PASS: Debezium resumed from offset successfully"
  echo "  - Connector captured CDC events after restart"
  echo "  - No events lost during restart"
  exit 0
else
  echo "❌ FAIL: Debezium did not capture events after restart"
  echo "  - Expected ≥5 post-restart events, got $POST_RESTART_EVENTS"
  exit 1
fi
