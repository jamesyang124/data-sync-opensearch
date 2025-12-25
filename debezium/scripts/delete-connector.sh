#!/bin/bash
set -e

# Delete Debezium connector via Kafka Connect REST API

# Error handling
trap 'echo ""; echo "✗ Script failed at line $LINENO. Check errors above."; exit 1' ERR

# Configuration
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="postgres-connector"

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

echo "=== Deleting Debezium Connector ==="
echo ""

# Run checks
check_dependencies

# Check if Kafka Connect is available
echo "Checking Kafka Connect availability..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$CONNECT_URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
  echo "✗ Kafka Connect is not available at $CONNECT_URL (HTTP: $HTTP_CODE)"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check if Kafka Connect is running: docker compose ps connect"
  echo "  2. Check Connect logs: docker compose logs connect --tail=50"
  echo "  3. Verify Connect URL: $CONNECT_URL"
  echo "  4. Start CDC services: make start-cdc"
  exit 1
fi

echo "✓ Kafka Connect is available"
echo ""

# Check if connector exists
echo "Checking if connector exists..."
EXISTING=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null || echo "{}")

if echo "$EXISTING" | jq -e '.error_code' &>/dev/null; then
  echo "✗ Connector '$CONNECTOR_NAME' not found"
  echo ""

  # List available connectors
  AVAILABLE=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null || echo "[]")
  if echo "$AVAILABLE" | jq -e 'length > 0' &>/dev/null; then
    echo "Available connectors:"
    echo "$AVAILABLE" | jq '.'
  else
    echo "No connectors registered."
  fi

  exit 1
fi

if ! echo "$EXISTING" | jq -e '.name' &>/dev/null; then
  echo "✗ Unexpected response format from Kafka Connect"
  echo "Response: $EXISTING"
  exit 1
fi

echo "✓ Connector found"
echo ""

# Delete connector
echo "Deleting connector '$CONNECTOR_NAME'..."
DELETE_RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" 2>/dev/null)
HTTP_CODE=$(echo "$DELETE_RESPONSE" | tail -n1)
BODY=$(echo "$DELETE_RESPONSE" | head -n-1)

if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
  echo "✓ Connector deleted successfully"
elif [ "$HTTP_CODE" = "404" ]; then
  echo "⚠ Connector not found (may have been deleted already)"
else
  echo "✗ Failed to delete connector (HTTP: $HTTP_CODE)"
  if [ -n "$BODY" ]; then
    echo "Response: $BODY"
  fi
  exit 1
fi

echo ""
echo "Remaining connectors:"
REMAINING=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null || echo "[]")
if echo "$REMAINING" | jq -e 'length > 0' &>/dev/null; then
  echo "$REMAINING" | jq '.'
else
  echo "[]"
  echo "(No connectors registered)"
fi
