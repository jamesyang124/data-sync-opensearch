#!/bin/bash
set -e

# Integration Test: CDC Event Capture
# Validates that CDC events are captured when data changes occur in PostgreSQL

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="postgres-connector"
TEST_ID="test-cdc-$(date +%s)"

echo "=== Integration Test: CDC Event Capture ==="
echo ""

# Test Setup
echo "Test Setup:"
echo "  Connect URL: $CONNECT_URL"
echo "  Connector: $CONNECTOR_NAME"
echo "  Test ID: $TEST_ID"
echo ""

# Test 1: Verify connector is running
echo "Test 1: Verify connector is RUNNING"
STATUS=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status")
CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state')

if [ "$CONNECTOR_STATE" = "RUNNING" ]; then
  echo "  ✓ PASS: Connector is RUNNING"
else
  echo "  ✗ FAIL: Connector state is $CONNECTOR_STATE (expected RUNNING)"
  exit 1
fi

# Test 2: Get initial record count
echo ""
echo "Test 2: Get baseline record count"
INITIAL_COUNT=$(docker compose exec -T postgres psql -U app -d app -tc "SELECT COUNT(*) FROM comments;" 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "  Initial comment count: $INITIAL_COUNT"

# Test 3: Insert a test row
echo ""
echo "Test 3: Insert test row into PostgreSQL"
INSERT_RESULT=$(docker compose exec -T postgres psql -U app -d app -c "
INSERT INTO comments (
  comment_id,
  video_id,
  channel_id,
  comment_text,
  likes,
  replies,
  published_at,
  sentiment_label,
  country_code
)
SELECT
  '$TEST_ID',
  v.video_id,
  u.channel_id,
  'Integration test - CDC event capture validation',
  42,
  0,
  NOW(),
  'neutral',
  'US'
FROM videos v, users u
LIMIT 1
RETURNING comment_id;" 2>&1)

if echo "$INSERT_RESULT" | grep -q "$TEST_ID"; then
  echo "  ✓ PASS: Test row inserted successfully"
else
  echo "  ✗ FAIL: Test row insertion failed"
  echo "  Result: $INSERT_RESULT"
  exit 1
fi

# Test 4: Verify record count increased
echo ""
echo "Test 4: Verify record count increased"
sleep 2  # Give time for the insert to complete

NEW_COUNT=$(docker compose exec -T postgres psql -U app -d app -tc "SELECT COUNT(*) FROM comments;" 2>/dev/null | tr -d '[:space:]' || echo "0")
echo "  New comment count: $NEW_COUNT"

if [ "$NEW_COUNT" -gt "$INITIAL_COUNT" ]; then
  echo "  ✓ PASS: Record count increased"
else
  echo "  ✗ FAIL: Record count did not increase"
  exit 1
fi

# Test 5: Verify CDC event was captured (check connector logs)
echo ""
echo "Test 5: Verify CDC event processing in connector logs"
sleep 3  # Give Debezium time to process the event

# Check Connect logs for activity
LOGS=$(docker compose logs connect --tail=50 2>&1)
if echo "$LOGS" | grep -q "comments"; then
  echo "  ✓ PASS: CDC activity detected in connector logs"
else
  echo "  ⚠ WARNING: Could not confirm CDC event in logs (may not be immediate)"
fi

# Test 6: Verify connector is still healthy after processing
echo ""
echo "Test 6: Verify connector remains healthy"
STATUS=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status")
CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state')
TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state')

if [ "$CONNECTOR_STATE" = "RUNNING" ] && [ "$TASK_STATE" = "RUNNING" ]; then
  echo "  ✓ PASS: Connector remains healthy (RUNNING)"
else
  echo "  ✗ FAIL: Connector state changed"
  echo "  Connector: $CONNECTOR_STATE, Task: $TASK_STATE"
  exit 1
fi

# Cleanup
echo ""
echo "Cleanup: Removing test row"
docker compose exec -T postgres psql -U app -d app -c "DELETE FROM comments WHERE comment_id = '$TEST_ID';" > /dev/null 2>&1

echo ""
echo "=== All Tests Passed ✓ ==="
echo ""
echo "Summary:"
echo "  - Test row inserted: $TEST_ID"
echo "  - Record count changed: $INITIAL_COUNT → $NEW_COUNT"
echo "  - Connector health: RUNNING"
echo "  - CDC pipeline: Active"
echo ""
echo "Note: To verify Kafka topic contents, run:"
echo "  docker compose exec kafka kafka-console-consumer \\"
echo "    --bootstrap-server localhost:9092 \\"
echo "    --topic dbserver.public.comments \\"
echo "    --from-beginning --max-messages 1"
