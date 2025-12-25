#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
# Usage: ./wait-for-postgres.sh [max_retries]

MAX_RETRIES=${1:-30}
RETRY_INTERVAL=2

echo "Waiting for PostgreSQL to be ready..."

for i in $(seq 1 $MAX_RETRIES); do
  if pg_isready -h localhost -p "${POSTGRES_PORT:-5432}" -U "${POSTGRES_USER:-app}" >/dev/null 2>&1; then
    echo "PostgreSQL is ready!"
    exit 0
  fi

  echo "Attempt $i/$MAX_RETRIES: PostgreSQL not ready yet, waiting ${RETRY_INTERVAL}s..."
  sleep $RETRY_INTERVAL
done

echo "ERROR: PostgreSQL did not become ready after $MAX_RETRIES attempts"
exit 1
