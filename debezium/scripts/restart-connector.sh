#!/bin/bash

# Restart Debezium connector (delete + re-register)

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DELETE_SCRIPT="$SCRIPT_DIR/delete-connector.sh"
REGISTER_SCRIPT="$SCRIPT_DIR/register-connector.sh"
WAIT_TIME=3

# Error handling
handle_error() {
  local exit_code=$1
  local step=$2
  echo ""
  echo "✗ Restart failed at $step (exit code: $exit_code)"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check Kafka Connect status: docker compose ps connect"
  echo "  2. Check Connect logs: docker compose logs connect --tail=100"
  echo "  3. Try manual steps:"
  echo "     - Delete: bash $DELETE_SCRIPT"
  echo "     - Register: bash $REGISTER_SCRIPT"
  exit "$exit_code"
}

# Validate scripts exist
validate_scripts() {
  local missing=()

  if [ ! -f "$DELETE_SCRIPT" ]; then
    missing+=("delete-connector.sh")
  fi

  if [ ! -f "$REGISTER_SCRIPT" ]; then
    missing+=("register-connector.sh")
  fi

  if [ ${#missing[@]} -ne 0 ]; then
    echo "✗ Missing required scripts: ${missing[*]}"
    echo "Expected location: $SCRIPT_DIR/"
    exit 1
  fi

  if [ ! -x "$DELETE_SCRIPT" ]; then
    echo "⚠ Making delete-connector.sh executable..."
    chmod +x "$DELETE_SCRIPT"
  fi

  if [ ! -x "$REGISTER_SCRIPT" ]; then
    echo "⚠ Making register-connector.sh executable..."
    chmod +x "$REGISTER_SCRIPT"
  fi
}

echo "=== Restarting Debezium Connector ==="
echo ""

# Validate scripts
validate_scripts

# Step 1: Delete existing connector
echo "Step 1: Deleting existing connector..."
echo "----------------------------------------"

# Allow deletion to fail if connector doesn't exist (404)
set +e
bash "$DELETE_SCRIPT"
DELETE_EXIT=$?
set -e

if [ $DELETE_EXIT -ne 0 ]; then
  echo ""
  echo "⚠ Warning: Delete step completed with warnings or errors (exit code: $DELETE_EXIT)"
  echo "Continuing with re-registration..."
fi

echo ""
echo "Waiting $WAIT_TIME seconds before re-registration..."
sleep "$WAIT_TIME"
echo ""

# Step 2: Re-register connector
echo "Step 2: Re-registering connector..."
echo "----------------------------------------"

if ! bash "$REGISTER_SCRIPT"; then
  handle_error $? "Step 2 (re-registration)"
fi

echo ""
echo "✅ Connector restart complete!"
echo ""
echo "Next steps:"
echo "  - Check status: make status-cdc"
echo "  - View in UI: http://localhost:8081 (Kafka UI)"
