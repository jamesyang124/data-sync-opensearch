#!/bin/bash
set -e

# Integration Test: Connector Registration
# Validates that the Debezium PostgreSQL connector can be registered successfully via REST API

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="postgres-connector"

echo "=== Integration Test: Connector Registration ==="
echo ""

# Test Setup
echo "Test Setup:"
echo "  Connect URL: $CONNECT_URL"
echo "  Connector: $CONNECTOR_NAME"
echo ""

# Test 1: Kafka Connect is reachable
echo "Test 1: Verify Kafka Connect is reachable"
if curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL" | grep -q "200"; then
  echo "  ✓ PASS: Kafka Connect is reachable"
else
  echo "  ✗ FAIL: Kafka Connect is not reachable"
  exit 1
fi

# Test 2: Register connector via REST API
echo ""
echo "Test 2: Register connector via REST API"

# Delete existing connector if present
if curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME" | grep -q "name"; then
  echo "  Cleaning up existing connector..."
  curl -s -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" > /dev/null
  sleep 2
fi

# Register connector
RESPONSE=$(curl -s -X POST \
  -H "Content-Type: application/json" \
  --data @"$PROJECT_ROOT/debezium/connectors/postgres-connector.json" \
  "$CONNECT_URL/connectors")

if echo "$RESPONSE" | grep -q '"name"'; then
  echo "  ✓ PASS: Connector registered successfully"
else
  echo "  ✗ FAIL: Connector registration failed"
  echo "  Response: $RESPONSE"
  exit 1
fi

# Test 3: Verify connector appears in connector list
echo ""
echo "Test 3: Verify connector appears in connector list"
CONNECTORS=$(curl -s "$CONNECT_URL/connectors")
if echo "$CONNECTORS" | grep -q "$CONNECTOR_NAME"; then
  echo "  ✓ PASS: Connector appears in list"
else
  echo "  ✗ FAIL: Connector not found in list"
  echo "  Connectors: $CONNECTORS"
  exit 1
fi

# Test 4: Verify connector status is RUNNING
echo ""
echo "Test 4: Verify connector status is RUNNING"
sleep 3  # Give connector time to start

STATUS=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status")
CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state')
TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state' 2>/dev/null || echo "NONE")

if [ "$CONNECTOR_STATE" = "RUNNING" ]; then
  echo "  ✓ PASS: Connector state is RUNNING"
else
  echo "  ✗ FAIL: Connector state is $CONNECTOR_STATE (expected RUNNING)"
  echo "  Status: $STATUS"
  exit 1
fi

if [ "$TASK_STATE" = "RUNNING" ]; then
  echo "  ✓ PASS: Task state is RUNNING"
else
  echo "  ✗ FAIL: Task state is $TASK_STATE (expected RUNNING)"
  exit 1
fi

# Test 5: Verify connector configuration matches
echo ""
echo "Test 5: Verify connector configuration"
CONFIG=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/config")

# Check key configuration parameters
if echo "$CONFIG" | grep -q '"connector.class":"io.debezium.connector.postgresql.PostgresConnector"'; then
  echo "  ✓ PASS: Connector class is correct"
else
  echo "  ✗ FAIL: Connector class mismatch"
  exit 1
fi

if echo "$CONFIG" | grep -q '"database.hostname":"postgres"'; then
  echo "  ✓ PASS: Database hostname is correct"
else
  echo "  ✗ FAIL: Database hostname mismatch"
  exit 1
fi

if echo "$CONFIG" | grep -q '"table.include.list":"public.videos,public.users,public.comments"'; then
  echo "  ✓ PASS: Table include list is correct"
else
  echo "  ✗ FAIL: Table include list mismatch"
  exit 1
fi

echo ""
echo "=== All Tests Passed ✓ ==="
echo ""
echo "Summary:"
echo "  - Kafka Connect: Reachable"
echo "  - Connector: Registered and RUNNING"
echo "  - Task: RUNNING"
echo "  - Configuration: Valid"
