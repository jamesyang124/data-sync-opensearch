#!/bin/bash
set -e

# Check Debezium connector status via Kafka Connect REST API

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

echo "=== Debezium Connector Status ==="
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

# Get connector status
echo "Fetching connector status..."
STATUS=$(curl -s "$CONNECT_URL/connectors/$CONNECTOR_NAME/status" 2>/dev/null || echo "{}")

# Check if connector exists
if echo "$STATUS" | jq -e '.error_code' &>/dev/null; then
  echo "✗ Connector '$CONNECTOR_NAME' not found"
  echo ""
  echo "Error: $(echo "$STATUS" | jq -r '.message // "Unknown error"')"
  echo ""

  # List available connectors
  AVAILABLE=$(curl -s "$CONNECT_URL/connectors" 2>/dev/null || echo "[]")
  if echo "$AVAILABLE" | jq -e 'length > 0' &>/dev/null; then
    echo "Available connectors:"
    echo "$AVAILABLE" | jq '.'
  else
    echo "No connectors registered."
  fi

  echo ""
  echo "To register the connector, run: make start-cdc"
  exit 1
fi

# Validate response format
if ! echo "$STATUS" | jq -e '.connector.state' &>/dev/null; then
  echo "✗ Unexpected response format from Kafka Connect"
  echo "Response: $STATUS"
  exit 1
fi

# Display formatted status
echo "Connector: $CONNECTOR_NAME"
echo "State: $(echo "$STATUS" | jq -r '.connector.state')"
echo ""

# Check if tasks array exists
if echo "$STATUS" | jq -e '.tasks | length > 0' &>/dev/null; then
  echo "Tasks:"
  echo "$STATUS" | jq '.tasks[]'
else
  echo "Tasks: None (connector may be starting)"
fi

echo ""
echo "Full status:"
echo "$STATUS" | jq '.'

# Check connector health
CONNECTOR_STATE=$(echo "$STATUS" | jq -r '.connector.state')
TASK_COUNT=$(echo "$STATUS" | jq '.tasks | length')

if [ "$CONNECTOR_STATE" = "RUNNING" ]; then
  if [ "$TASK_COUNT" -gt 0 ]; then
    TASK_STATE=$(echo "$STATUS" | jq -r '.tasks[0].state')

    if [ "$TASK_STATE" = "RUNNING" ]; then
      echo ""
      echo "✅ Connector is healthy and running"
      exit 0
    else
      echo ""
      echo "⚠ Warning: Connector is RUNNING but task state is $TASK_STATE"

      # Show task error trace if available
      if echo "$STATUS" | jq -e '.tasks[0].trace' &>/dev/null; then
        echo ""
        echo "Task error trace:"
        echo "$STATUS" | jq -r '.tasks[0].trace'
      fi

      echo ""
      echo "Troubleshooting:"
      echo "  1. Check Connect logs: docker compose logs connect --tail=100"
      echo "  2. Verify PostgreSQL is running: docker compose ps postgres"
      echo "  3. Restart connector: make restart-cdc"
      exit 1
    fi
  else
    echo ""
    echo "⚠ Warning: Connector is RUNNING but has no tasks yet"
    echo "This may be temporary during startup. Check again in a few seconds."
    exit 0
  fi
elif [ "$CONNECTOR_STATE" = "FAILED" ]; then
  echo ""
  echo "✗ Connector is in FAILED state"

  # Show connector error trace if available
  if echo "$STATUS" | jq -e '.connector.trace' &>/dev/null; then
    echo ""
    echo "Connector error trace:"
    echo "$STATUS" | jq -r '.connector.trace'
  fi

  echo ""
  echo "Troubleshooting:"
  echo "  1. Check Connect logs: docker compose logs connect --tail=100"
  echo "  2. Verify PostgreSQL connectivity: docker compose exec postgres pg_isready -U app"
  echo "  3. Check PostgreSQL replication slot: docker compose exec postgres psql -U app -d app -c \"SELECT * FROM pg_replication_slots;\""
  echo "  4. Restart connector: make restart-cdc"
  exit 1
else
  echo ""
  echo "⚠ Connector state: $CONNECTOR_STATE"
  echo ""
  echo "Common states:"
  echo "  - UNASSIGNED: Connector is being assigned to a worker"
  echo "  - PAUSED: Connector is paused"
  echo "  - RESTARTING: Connector is restarting"

  if [ "$TASK_COUNT" -gt 0 ]; then
    echo ""
    echo "Task state: $(echo "$STATUS" | jq -r '.tasks[0].state // "Unknown"')"
  fi

  exit 0
fi
