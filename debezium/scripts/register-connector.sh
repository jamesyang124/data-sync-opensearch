#!/bin/bash
set -e

# Register Debezium PostgreSQL connector via Kafka Connect REST API

# Error handling
trap 'echo ""; echo "✗ Script failed at line $LINENO. Check errors above."; exit 1' ERR

# Configuration
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="postgres-connector"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONNECTOR_CONFIG="$PROJECT_ROOT/debezium/connectors/postgres-connector.json"

# Dependency checks
check_dependencies() {
  local missing_deps=()

  if ! command -v curl &> /dev/null; then
    missing_deps+=("curl")
  fi

  if ! command -v jq &> /dev/null; then
    missing_deps+=("jq")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "✗ Missing required dependencies: ${missing_deps[*]}"
    echo ""
    echo "Install with:"
    echo "  macOS: brew install ${missing_deps[*]}"
    echo "  Ubuntu/Debian: sudo apt-get install ${missing_deps[*]}"
    echo "  CentOS/RHEL: sudo yum install ${missing_deps[*]}"
    exit 1
  fi
}

# Validate inputs
validate_inputs() {
  if [ ! -f "$CONNECTOR_CONFIG" ]; then
    echo "✗ Connector configuration file not found: $CONNECTOR_CONFIG"
    echo ""
    echo "Expected location: debezium/connectors/postgres-connector.json"
    exit 1
  fi

  if ! jq empty "$CONNECTOR_CONFIG" 2>/dev/null; then
    echo "✗ Connector configuration file is not valid JSON: $CONNECTOR_CONFIG"
    exit 1
  fi
}

echo "=== Registering Debezium PostgreSQL Connector ==="
echo ""
echo "Connect URL: $CONNECT_URL"
echo "Connector: $CONNECTOR_NAME"
echo "Config: $CONNECTOR_CONFIG"
echo ""

# Run checks
check_dependencies
validate_inputs

# Wait for Kafka Connect to be ready
echo "Waiting for Kafka Connect to be ready..."
MAX_WAIT=30
WAIT_COUNT=0

while [ $WAIT_COUNT -lt $MAX_WAIT ]; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL" 2>/dev/null || echo "000")

  if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Kafka Connect is ready"
    break
  fi

  echo "  Waiting... ($((WAIT_COUNT + 1))/$MAX_WAIT) [HTTP: $HTTP_CODE]"
  sleep 2
  WAIT_COUNT=$((WAIT_COUNT + 1))
done

if [ $WAIT_COUNT -eq $MAX_WAIT ]; then
  echo "✗ Kafka Connect not ready after ${MAX_WAIT} attempts"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if Kafka Connect is running: docker compose ps connect"
  echo "  2. Check Connect logs: docker compose logs connect --tail=50"
  echo "  3. Verify Connect URL is correct: $CONNECT_URL"
  echo "  4. Start CDC services if needed: make start-cdc"
  exit 1
fi

echo ""

# Check if connector already exists
echo "Checking for existing connector..."
EXISTING=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || echo "{}")

if echo "$EXISTING" | jq -e '.name' &>/dev/null; then
  echo "⚠ Connector '$CONNECTOR_NAME' already exists. Deleting..."

  DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null)
  HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)

  if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
    echo "✓ Existing connector deleted"
    sleep 2
  else
    echo "✗ Failed to delete existing connector (HTTP: $HTTP_CODE)"
    echo "Response: $(echo "$DELETE_RESPONSE" | sed '$d')"
    exit 1
  fi
else
  echo "✓ No existing connector found"
fi

echo ""

# Register connector
echo "Registering connector..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Content-Type: application/json" \
  --data @"$CONNECTOR_CONFIG" \
  "$CONNECT_URL/connectors" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

# Check if registration succeeded
if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
  if echo "$BODY" | jq -e '.name' &>/dev/null; then
    echo "✓ Connector registered successfully"
    echo ""
    echo "Connector details:"
    echo "$BODY" | jq '.'
  else
    echo "✗ Unexpected response format (HTTP: $HTTP_CODE)"
    echo "Response: $BODY"
    exit 1
  fi
else
  echo "✗ Failed to register connector (HTTP: $HTTP_CODE)"
  echo ""
  if echo "$BODY" | jq -e '.message' &>/dev/null; then
    echo "Error: $(echo "$BODY" | jq -r '.message')"
  else
    echo "Response: $BODY"
  fi
  echo ""
  echo "Troubleshooting:"
  echo "  1. Verify PostgreSQL is running: docker compose ps postgres"
  echo "  2. Check PostgreSQL connectivity: docker compose exec postgres pg_isready -U app"
  echo "  3. Verify connector config: cat $CONNECTOR_CONFIG | jq '.'"
  exit 1
fi

echo ""
echo "Checking connector status..."
sleep 2

STATUS=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status" 2>/dev/null || echo "{}")
if echo "$STATUS" | jq -e '.connector.state' &>/dev/null; then
  echo "$STATUS" | jq '.'

  CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state')
  if [ "$CONNECTOR_STATE" != "RUNNING" ]; then
    echo ""
    echo "⚠ Warning: Connector state is $CONNECTOR_STATE (expected RUNNING)"
    echo "This may be temporary. Check status in a few seconds: make status-cdc"
  fi
else
  echo "⚠ Could not retrieve connector status"
fi

echo ""
echo "✅ Connector registration complete!"
echo ""
echo "Next steps:"
echo "  - Check status: make status-cdc"
echo "  - View in UI: http://localhost:8081 (Kafka UI)"
echo "  - View topics: docker compose exec kafka kafka-topics --bootstrap-server localhost:9092 --list"
